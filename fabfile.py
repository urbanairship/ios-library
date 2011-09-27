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
    fab.local("tar czf ios_docs.tgz -C docs/html .")
    print "Done! Uploading now..."
    fab.put("ios_docs.tgz", "/django/docs/ios_lib/ios_docs.tgz")
    print "Done! Untar'ing docs remotely..."
    fab.run("cd /django/docs/ios_lib/ && tar xzf ios_docs.tgz && rm ios_docs.tgz")
    fab.local("rm ios_docs.tgz")
    print "Thanks, have a nice day!"

def build_and_upload_docs():
    build_docs()
    upload_docs()
