# Code Ready Workspaces APB Installer and Stack Builder

## What's Inside

This repository contains:
* apb/ :: ansible playbook bundle file for Code Ready Workspaces installer, as well as an installer script
* assembly/ :: maven build to fetch 3rd party deps we need to include in the stack image builds
* product/ :: script to set up proxy config to build in Project Newcastle (NCL) server 
* stacks/ :: Dockerfiles for stack images, as well as a script that builds them.

See individual folders for more README.md files.

To build stacks in OSBS, see http://pkgs.devel.redhat.com/cgit/apbs/codeready-workspaces/tree/README.adoc?h=codeready-1.0-rhel-7
