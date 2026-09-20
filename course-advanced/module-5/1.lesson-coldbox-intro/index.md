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
  name: cf-training-advanced-7442b9e0

challenges:
  coldbox-intro-c174c787: {}

tasks:
  verify_coldbox_installed:
    machine: cf-dev
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/coldbox" ]; then
        echo "ColdBox not installed — run: box install coldbox"
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
