// Node ≥20 ESM – no external dependencies
import fs from 'fs/promises';
import path from 'path';
import process from 'process';

const MAX_DIFF_BYTES = 400_000;                         // ~100 k tokens
const MODEL_ID_FROM_ENV = process.env.MODEL_ID;
const MODEL_ID = MODEL_ID_FROM_ENV || 'gemini-pro';
if (!MODEL_ID_FROM_ENV) {
    warn(`MODEL_ID environment variable not set, falling back to default: ${MODEL_ID}. Ensure this is intended and configured in the workflow.`);
}
const DEBUG = process.env.DEBUG === 'true';
const root = process.cwd();
const log = (m) => console.log(`🪄 ${m}`);
const warn = (m) => console.warn(`⚠️  ${m}`);
const die = (m) => { console.error(`💥 ${m}`); process.exit(1); };

(async () => {
    // ─── Diff ─────────────────────────────────────────────
    const diff = await fs.readFile(path.join(root, 'diff.patch'), 'utf8');
    log(`Diff loaded (${(diff.length / 1024).toFixed(1)} KB)`);

    if (diff.length > MAX_DIFF_BYTES) {
        warn(`Diff > ${(MAX_DIFF_BYTES / 1024)} KB ⇒ skipping AI review`);
        return;
    }
    
    // ─── Prompt ───────────────────────────────────────────
    const promptPath = path.join(root, 'scripts', 'gemini-review-prompt.md');
    const prompt = await fs.readFile(promptPath, 'utf8');

    // ─── Validate API key ───────────────────────────────────
    if (!process.env.GEMINI_API_KEY) {
        die('GEMINI_API_KEY environment variable is not set');
    }

    // ─── Gemini call ─────────────────────────────────────
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL_ID}:generateContent?key=${process.env.GEMINI_API_KEY}`;
    log(`Calling Gemini (${MODEL_ID}) …`);

    const gemRes = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            contents: [{
                parts: [{ text: `${prompt}\n\n---\n\n${diff}` }]
            }],
            generationConfig: {
                temperature: 0.2,
                topK: 1,
                topP: 0.95
            }
        })
    });

    if (!gemRes.ok) {
        // Extra diagnostics for the common 403
        if (gemRes.status === 403) {
            die(`Gemini HTTP 403 ➜ Check that:
 • Generative Language API is **enabled** in your Google Cloud project
 • The API key has **no application restrictions** (or allows server IPs)
 • MODEL_ID (“${MODEL_ID}”) is available to your key`);
        }
        die(`Gemini HTTP ${gemRes.status}`);
    }

    const gemJson = await gemRes.json();
    
    // Better error handling for Gemini response
    if (gemJson.error) {
        die(`Gemini API error: ${gemJson.error.message || JSON.stringify(gemJson.error)}`);
    }
    
    if (!gemJson.candidates || !gemJson.candidates.length) {
        if (DEBUG) {
            console.log('Full Gemini response:', JSON.stringify(gemJson, null, 2));
        }
        die('Gemini returned no candidates');
    }
    
    // Check for blocked or filtered responses
    const candidate = gemJson.candidates[0];
    if (candidate.finishReason && candidate.finishReason !== 'STOP') {
        warn(`Response finish reason: ${candidate.finishReason}`);
        if (candidate.finishReason === 'SAFETY') {
            warn('Response blocked by safety filters');
            if (DEBUG && candidate.safetyRatings) {
                console.log('Safety ratings:', JSON.stringify(candidate.safetyRatings, null, 2));
            }
        }
    }
    
    // Log the structure to debug
    if (DEBUG) {
        console.log('Candidate structure:', JSON.stringify(candidate, null, 2));
    }
    
    const gemText = candidate?.content?.parts?.[0]?.text ?? '';
    log(`Gemini returned ${(gemText.length / 1024).toFixed(1)} KB`);

    if (!gemText.trim()) {
        warn('Gemini response empty – nothing to post');
        if (DEBUG) {
            console.log('Full candidate:', JSON.stringify(candidate, null, 2));
        }
        return;
    }

    if (DEBUG) {
        console.log('=== GEMINI RESPONSE START ===');
        console.log(gemText);
        console.log('=== GEMINI RESPONSE END ===');
    }

    // ─── Handle LGTM response ─────────────────────────────
    if (gemText.trim() === 'LGTM 🤖👍') {
        log('No issues found - posting LGTM');
        const ghRes = await fetch(
            `https://api.github.com/repos/${process.env.REPO}/pulls/${process.env.PR_NUMBER}/reviews`,
            {
                method: 'POST',
                headers: {
                    'Authorization': `token ${process.env.GITHUB_TOKEN}`,
                    'Accept': 'application/vnd.github+json'
                },
                body: JSON.stringify({
                    body: 'LGTM 🤖👍',
                    event: 'COMMENT'
                })
            }
        );
        if (!ghRes.ok) die(`GitHub HTTP ${ghRes.status}`);
        log('LGTM posted successfully');
        return;
    }

    // ─── Parse suggestions ───────────────────────────────
    const comments = [];
    
    // First check if response contains "Code Suggestions" header
    const suggestionsSection = gemText.match(/###?\s*Code Suggestions\s*\n([\s\S]*)/)?.[1] || gemText;
    const blocks = suggestionsSection.split(/^-{3,}$/m).map(s => s.trim()).filter(Boolean);

    for (const b of blocks) {
        // Skip if block is too short or looks like a header
        if (b.length < 20 || b.match(/^#+\s/)) continue;
        
        // Clean up duplicate File: lines (from examples in prompt)
        const cleanedBlock = b.replace(/^File:.*\nFile:/m, 'File:');
        
        // More flexible regex patterns for parsing
        const fileMatch = cleanedBlock.match(/^File:\s*(.+?)$/m);
        const lineMatch = cleanedBlock.match(/^Line:\s*(\d+)/m);
        const commentMatch = cleanedBlock.match(/^Comment:\s*(.+?)$/m);
        const suggestionMatch = cleanedBlock.match(/```suggestion\n([\s\S]*?)\n```/);
        
        if (fileMatch && lineMatch && commentMatch && suggestionMatch) {
            const file = fileMatch[1].trim();
            const line = parseInt(lineMatch[1], 10);
            const comment = commentMatch[1].trim();
            const suggestion = suggestionMatch[1];
            
            // Validate line number
            if (isNaN(line) || line < 1) {
                warn(`Invalid line number ${line} for file ${file}`);
                continue;
            }
            
            // Clean up file path (remove duplicate "File:" prefix if present)
            const cleanFile = file.replace(/^File:\s*/, '');
            
            // Skip if this looks like an example from the prompt
            if (cleanFile.includes('ProfileView.swift') && line === 42) {
                if (DEBUG) console.log('Skipping example suggestion from prompt');
                continue;
            }
            
            const body = `${comment}\n\`\`\`suggestion\n${suggestion}\n\`\`\``;
            comments.push({ path: cleanFile, line, side: 'RIGHT', body });
        } else if (b.includes('File:') || b.includes('Line:')) {
            // Only warn if it looks like a suggestion block but failed to parse
            if (DEBUG) {
                console.log('Failed to parse block:');
                console.log('File match:', fileMatch);
                console.log('Line match:', lineMatch);
                console.log('Comment match:', commentMatch);
                console.log('Has suggestion:', !!suggestionMatch);
                console.log('Block content:', b.slice(0, 200));
            }
            warn(`Unparsable block (missing ${!fileMatch ? 'file' : !lineMatch ? 'line' : !commentMatch ? 'comment' : 'suggestion'})`);
        }
    }
    log(`Parsed ${comments.length} suggestion(s)`);

    if (!comments.length) {
        log('No suggestions found after parsing');
        
        // Post a comment indicating the review ran but found no specific issues
        const ghRes = await fetch(
            `https://api.github.com/repos/${process.env.REPO}/pulls/${process.env.PR_NUMBER}/reviews`,
            {
                method: 'POST',
                headers: {
                    'Authorization': `token ${process.env.GITHUB_TOKEN}`,
                    'Accept': 'application/vnd.github+json'
                },
                body: JSON.stringify({
                    body: '🤖 **Code review completed** - No issues found',
                    event: 'COMMENT'
                })
            }
        );
        if (!ghRes.ok) warn(`Failed to post completion comment: ${ghRes.status}`);
        return;
    }

    // ─── Post review ─────────────────────────────────────
    log('Posting review to GitHub…');
    const ghRes = await fetch(
        `https://api.github.com/repos/${process.env.REPO}/pulls/${process.env.PR_NUMBER}/reviews`,
        {
            method: 'POST',
            headers: {
                'Authorization': `token ${process.env.GITHUB_TOKEN}`,
                'Accept': 'application/vnd.github+json'
            },
            body: JSON.stringify({
                body: `🤖 **Code Review** - Found ${comments.length} suggestion${comments.length === 1 ? '' : 's'}`,
                event: 'COMMENT',
                comments
            })
        }
    );

    if (!ghRes.ok) die(`GitHub HTTP ${ghRes.status}`);
    log('Review posted successfully 🎉');
})().catch((e) => die(e.stack || e));