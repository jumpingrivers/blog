# Copy the shared R files into mcp/R so this folder deploys on its own.
# Run from the project root: Rscript mcp/build.R
files <- c("data.R", "tools.R", "wrap.R", "audit.R")
dir.create(file.path("mcp", "R"), showWarnings = FALSE)
stopifnot(all(file.copy(file.path("R", files), file.path("mcp", "R", files), overwrite = TRUE)))
