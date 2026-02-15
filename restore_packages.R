#!/usr/bin/env Rscript

# Restore renv packages
cat("Starting package restoration...\n")
renv::restore(prompt = FALSE)
cat("Package restoration complete!\n")
