---
kind: lesson

title: What is ColdBox? MVC Architecture & Why Frameworks

description: |
  Understand what ColdBox solves, how MVC maps to ColdFusion concepts,
  and when to choose a framework over raw CFML pages.

createdAt: 2026-09-03
updatedAt: 2026-09-03

playground:
  name: cf-alex-edcdf975

tasks:
  verify_coldbox_installed:
    machine: dev-machine
    user: laborant
    run: |
      if [ ! -d "/home/laborant/app/coldbox" ]; then
        echo "ColdBox not installed — run: box install coldbox"
        exit 1
      fi
      echo "ColdBox installed"
---
