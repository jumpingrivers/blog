# Taken from plumber quickstart documentation
# https://www.rplumber.io/articles/quickstart.html
#* @get /echo
function(msg=""){
  list(msg = paste0("The message is: '", msg, "'"))
}
