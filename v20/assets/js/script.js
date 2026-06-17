

const root = document.documentElement;

function applyTheme(theme) {
    try {
        root.setAttribute('data-theme', theme);
        localStorage.setItem('theme', theme);
        
        // Update button text to reflect current theme
        const button = document.querySelector('.theme-toggle');
        if (button) {
            button.setAttribute('aria-label', 
                                `Switch to ${theme === 'dark' ? 'light' : 'dark'} theme`
                                );
        }
    } catch (error) {
        console.warn('Failed to apply theme:', error);
    }
}

function toggleTheme() {
    const current = root.getAttribute('data-theme');
    applyTheme(current === 'dark' ? 'light' : 'dark');
}

// Enhanced keyboard navigation
function handleKeyboardNavigation(event) {
    // Allow Enter or Space to activate theme toggle
    if ((event.key === 'Enter' || event.key === ' ') && 
        event.target.classList.contains('theme-toggle')) {
        event.preventDefault();
        toggleTheme();
    }
}

// Error handling for missing logo image
function handleImageError(img) {
    img.style.display = 'none';
    console.warn('Logo image not found:', img.src);
}

// Load saved theme preference or system default
(function initializeTheme() {
    try {
        const saved = localStorage.getItem('theme');
        if (saved === 'light' || saved === 'dark') {
            applyTheme(saved);
        } else {
            const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
            applyTheme(prefersDark ? 'dark' : 'light');
        }
        
        // Listen for system theme changes
        const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
        mediaQuery.addEventListener('change', (e) => {
            const saved = localStorage.getItem('theme');
            if (!saved || (saved !== 'light' && saved !== 'dark')) {
                applyTheme(e.matches ? 'dark' : 'light');
            }
        });
    } catch (error) {
        console.warn('Failed to initialize theme:', error);
        // Fallback to light theme
        root.setAttribute('data-theme', 'light');
    }
})();

// Add event listeners when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    // Add keyboard support
    document.addEventListener('keydown', handleKeyboardNavigation);
    
    // Add error handling for logo image
    const logo = document.querySelector('.logo');
    if (logo) {
        logo.addEventListener('error', () => handleImageError(logo));
        
        // Preload check - if image fails to load immediately
        if (logo.complete && !logo.naturalWidth) {
            handleImageError(logo);
        }
    }
    
    // Add focus management for better accessibility
    const cards = document.querySelectorAll('.module-card');
    cards.forEach((card, index) => {
        const link = card.querySelector('.module-link');
        if (link) {
            // Add tab index for keyboard navigation
            link.setAttribute('tabindex', '0');
            
            // Add focus styles
            link.addEventListener('focus', () => {
                card.style.outline = '2px solid var(--link-light)';
                card.style.outlineOffset = '2px';
            });
            
            link.addEventListener('blur', () => {
                card.style.outline = 'none';
            });
        }
    });
});

