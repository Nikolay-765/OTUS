#!/bin/bash

rm -rf /var/backup/*
borg init --encryption=repokey /var/backup/
