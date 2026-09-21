---
kind: lesson

title: What is ColdBox? MVC Architecture & Why Frameworks

description: |
  Understand what ColdBox solves, how MVC maps to ColdFusion concepts,
  and when to choose a framework over raw CFML pages.

name: coldbox-intro-mvc
slug: coldbox-intro-mvc

createdAt: 2026-09-03
updatedAt: 2026-09-03

categories:
- programming

tagz:
- coldfusion
- coldbox
- mvc

playground:
  name: cf-training-devops-3039c6bb

challenges:
  coldbox-intro-c174c787: {}

tasks:
  verify_coldbox_installed:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/coldbox" ]; then
        echo "ColdBox not installed — run: cd /home/laborant/app && box install coldbox"
        exit 1
      fi
      if [ ! -f "/home/laborant/app/coldbox/system/Bootstrap.cfc" ]; then
        echo "ColdBox directory exists but appears incomplete"
        exit 1
      fi
      echo "ColdBox installed ✓"

  verify_lesson_complete:
    machine: cf-dev
    user: laborant
    needs:
      - verify_coldbox_installed
    run: |
      echo "ColdBox intro lesson complete ✓"
---
