#---------------------------------------------#
# DO NOT EDIT THIS FILE OR ADD ANYTHING TO IT #
#---------------------------------------------#

#' Dependencies
#' 
#' @param modules JavaScript files names that require 
#' the `type = module`.
#' @importFrom htmltools htmlDependency
#' 
#' @keywords internal
serveAssets <- function(modules = NULL){
	# JavaScript files
	javascript <- list.files(
		system.file(package = "shinyGreeter"), 
		recursive = TRUE, 
		pattern = ".js$"
	)

	modules <- get_modules(javascript, modules)
	javascript <- remove_modules(javascript, modules)

	# CSS files
	css <- list.files(
		system.file(package = "shinyGreeter"), 
		recursive = TRUE,
		pattern = ".css$"
	)
	
	# so dependency processes correctly
	names(css) <- rep("file", length(css))
	names(javascript) <- rep("file", length(javascript))

	# serve dependencies
	dependencies <- list()
	
	standard <- htmlDependency(
		"shinyGreeter",
		version = utils::packageVersion("shinyGreeter"),
		package = "shinyGreeter",
		src = ".",
		script = javascript,
		stylesheet = css
	)
	dependencies <- append(dependencies, list(standard))

	if(!is.null(modules)){
		modules <- htmlDependency(
			"shinyGreeter-modules",
			version = utils::packageVersion("shinyGreeter"),
			package = "shinyGreeter",
			src = ".",
			script = modules,
			meta = list(type = "module")
		)
		dependencies <- append(dependencies, list(modules))
	}

	return(dependencies)
}

#' Module
#' 
#' Retrieve and add modules from a vector of files.
#' 
#' @param files JavaScript files
#' @param modules JavaScript files names that require 
#' the `type = module`.
#' @importFrom htmltools htmlDependency
#' 
#' @keywords internal
#' @name js-modules
remove_modules <- function(files, modules){
	if(is.null(modules))
		return(files)

	# make pattern
	pattern <- collapse_files(modules)

	# remove modules
	files[!grepl(pattern, files)]
}

#' @rdname js-modules
#' @keywords internal
get_modules <- function(files, modules){
	if(is.null(modules))
		return(NULL)

	# make pattern
	pattern <- collapse_files(modules)

	# remove modules
	files[grepl(pattern, files)]
}

# collapse files into a pattern
collapse_files <- function(files){
	pattern <- paste0(files, collapse = "$|")
	paste0(pattern, "$")
}

#---------------------------------------------#
# DO NOT EDIT THIS FILE OR ADD ANYTHING TO IT #
#---------------------------------------------#
