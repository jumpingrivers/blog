root <- normalizePath(test_path("..", ".."))
for (file in list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)) {
  source(file)
}
