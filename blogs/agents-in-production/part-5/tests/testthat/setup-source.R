root <- normalizePath(test_path("..", ".."))
for (file in list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)) {
  source(file)
}
if (file.exists(file.path(root, "evals", "helpers.R"))) {
  source(file.path(root, "evals", "helpers.R"))
}
