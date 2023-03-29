#!/bin/bash
for i in *.db; do sort -o $i $i; done
