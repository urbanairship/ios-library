import os

from fabric import api as fab


fab.env.hosts = ["urbanairship.com"]
fab.env.user = "django"

def hello():
    print "Hello."

def build_docs():
    fab.local("./build_docs.sh", capture=False)

def upload_docs():
    print "Creating tar of docs..."
    fab.local("tar czf ios_inbox_docs.tgz -C docs/html .")
    print "Done! Uploading now..(except not actually)"
    #fab.put("ios_inbox_docs.tgz", "/django/docs/wherever_this_goes/ios_inbox_docs.tgz")
    print "Done! Untar'ing docs remotely..(except not actually)"
    #fab.run("cd /django/docs/wherever_this_goes/ && tar xzf ios_inbox_docs.tgz && rm ios_inbox_docs.tgz")
    fab.local("rm ios_inbox_docs.tgz")
    print "Thanks, have a nice day!"

def build_and_upload_docs():
    build_docs()
    upload_docs()
