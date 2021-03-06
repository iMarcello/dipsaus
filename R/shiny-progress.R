#' 'Shiny' progress bar, but can run without reactive context
#' @param title character, task description
#' @param max maximum number of items in the queue
#' @param ... passed to \code{shiny::Progress$new(...)}
#' @param quiet suppress console output, ignored in shiny context.
#' @param session 'shiny' session, default is current reactive domain
#' @param shiny_auto_close logical, automatically close 'shiny' progress bar
#' once current observer is over. Default is \code{FALSE}. If setting to
#' \code{TRUE}, then it's equivalent to
#' \code{p <- progress2(...); on.exit({p$close()}, add = TRUE)}.
#'
#' @return A list of functions:
#' \describe{
#' \item{\code{inc(detail, message = NULL, amount = 1, ...)}}{
#' Increase progress bar by \code{amount} (default is 1).
#' }
#' \item{\code{close()}}{
#' Close the progress
#' }
#' \item{\code{reset(detail = '', message = '', value = 0)}}{
#' Reset the progress to \code{value} (default is 0), and reset information
#' }
#' \item{\code{get_value()}}{
#' Get current progress value
#' }
#' \item{\code{is_closed()}}{
#' Returns logical value if the progress is closed or not.
#' }
#' }
#'
#' @examples
#'
#' progress <- progress2('Task A', max = 2)
#' progress$inc('Detail 1')
#' progress$inc('Detail 2')
#' progress$close()
#'
#' # Check if progress is closed
#' progress$is_closed()
#'
#' # ------------------------------ Shiny Example ------------------------------
#' library(shiny)
#' library(dipsaus)
#'
#' ui <- fluidPage(
#'   actionButtonStyled('do', 'Click Here', type = 'primary')
#' )
#'
#' server <- function(input, output, session) {
#'   observeEvent(input$do, {
#'     updateActionButtonStyled(session, 'do', disabled = TRUE)
#'     progress <- progress2('Task A', max = 10, shiny_auto_close = TRUE)
#'     lapply(1:10, function(ii){
#'       progress$inc(sprintf('Detail %d', ii))
#'       Sys.sleep(0.2)
#'     })
#'     updateActionButtonStyled(session, 'do', disabled = FALSE)
#'   })
#' }
#'
#' if(interactive()){
#'   shinyApp(ui, server)
#' }
#'
#' @export
progress2 <- function( title, max = 1, ..., quiet = FALSE,
                       session = shiny::getDefaultReactiveDomain(),
                       shiny_auto_close = FALSE){
  if(missing(title) || is.null(title)){ title <- '' }
  if( length(title) > 1 ){ title <- paste(title, collapse = '')}

  if( inherits(session, c('ShinySession', 'session_proxy', 'R6')) ){
    within_shiny <- TRUE
  }else{
    within_shiny <- FALSE
  }

  current <- 0
  closed <- FALSE
  get_value <- function(){ current }
  is_closed <- function(){ closed }
  logger <- function(..., .quiet = quiet){
    if(!.quiet){
      cat2(...)
    }
  }

  if( quiet || !within_shiny ){
    progress <- NULL
    logger(sprintf("[%s]: initializing...", title), level = 'DEFAULT', bullet = 'play')

    inc <- function(detail, message = NULL, amount = 1, ...){
      stopifnot2(!closed, msg = 'progress is closed')
      quiet <- c(list(...)[['quiet']], quiet)[[1]]
      # if message is updated
      if(!is.null(message) && length(message) == 1){ title <<- message }
      current <<- amount + current
      logger(sprintf("[%s]: %s (%d out of %d)", title, detail, current, max),
           level = 'DEFAULT', bullet = 'arrow_right', .quiet = quiet)
    }

    close <- function(){
      closed <<- TRUE
      logger('Finished', level = 'DEFAULT', bullet = 'stop')
    }
    reset <- function(detail = '', message = '', value = 0){
      title <<- message
      current <<- value
    }

  }else{
    progress <- shiny::Progress$new(session = session, max = max, ...)
    inc <- function(detail, message = NULL, amount = 1, ...){
      if(!is.null(message) && length(message) == 1){ title <<- message }
      progress$inc(detail = detail, message = title, amount = amount)
    }
    close <- function(){
      if(!closed){
        progress$close()
        closed <<- TRUE
      }
    }
    reset <- function(detail = '', message = '', value = 0){
      title <<- message
      current <<- value
      progress$set(value = value, message = title, detail = detail)
    }
    if(shiny_auto_close){
      parent_frame <- parent.frame()
      do.call(
        on.exit, list(substitute(close()), add = TRUE),
        envir = parent_frame
      )
    }

  }

  return(list(
    .progress = progress,
    inc = inc,
    close = close,
    reset = reset,
    get_value = get_value,
    is_closed = is_closed
  ))
}


