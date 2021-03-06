

#' @name queue
#' @title Create R object queue.
#' @description Provides five types of queue that fit in different use cases.
#' @return An \code{R6} instance that inherits \code{\link[dipsaus]{AbstractQueue}}
#' @details There are five types of queue implemented. They all inherit class
#' \code{\link[dipsaus]{AbstractQueue}}. There are several differences in
#' use case scenarios and they backend implementations.
#'
#' \describe{
#' \item{\code{\link{session_queue}}}{
#' A session queue takes a \code{\link[fastmap]{fastmap}} object. All objects are stored in
#' current R session. This means you cannot access the queue from other process
#' nor parent process. The goal of this queue is to share the data across
#' different environments and to store global variables, as long as they share
#' the same map object. If you are looking for queues that can be shared
#' by different processes, check the rest queue types.
#' }
#' \item{\code{\link{rds_queue}}}{
#' A 'RDS' queue uses file system to store values. The values are stored
#' separately in '.rds' files. Compared to session queues, 'RDS' queue can be
#' shared across different R process. However, because each value is stored
#' as a file, cleaning a queue would be slow, hence it's recommended to store
#' large files in \code{rds_queue}. If the value is not large in RAM,
#' \code{text_queue} and \code{redis_queue} are recommended.
#' }
#' \item{\code{\link{qs_queue}}}{
#' A 'qs' queue uses package 'qs' as backend. This queue is very similar to
#' \code{rds_queue}, but is especially designed for large values. For example,
#' pushing 1GB data to \code{qs_queue} will be 100 times faster than using
#' \code{rds_queue}, and \code{text_queue} will almost fail. However, compared
#' to \code{rds_queue} the stored data cannot be normally read by R as they
#' are compressed binary files. And \code{qs_queue} is heavier than
#' \code{text_queue}.
#' }
#' \item{\code{\link{text_queue}}}{
#' A 'text' queue uses file system to store values. Similar to \code{rds_queue},
#' it can be stored across multiple processes as long as the queues share the
#' same file directory. Compared to \code{rds_queue}, \code{text_queue}
#' serialize values as strings and stores them as a text table. It's much
#' lighter but limited. For example, all other queue types can store environment
#' and functions. Though \code{text_queue} can also store complicated structures,
#' The speed is much slower (could freeze the whole process). Therefore, it's
#' highly recommended to use \code{redis_queue}, \code{qs_queue}, and
#' \code{rds_queue} if speed is not the major concern.
#' }
#' \item{\code{\link{redis_queue}}}{
#' A 'Redis' queue uses free open source software `Redis` and R package
#' 'RcppRedis' as backend. Compared to session queue, 'Redis' queue can be
#' shared across sessions. Compared to 'text' and 'rds' queues, 'Redis' queue
#' stores data in memory, meaning a potential of significant speed ups. To use
#' \code{redis_queue}, you need to install `Redis` on your computer.
#' \itemize{
#'   \item On Mac: use `\code{brew install redis}` to install and
#'     `\code{brew services start redis}` to start the service
#'   \item On Linux: use `\code{sudo apt-get install redis-server}` to install
#'     and `\code{sudo systemctl enable redis-server.service}` to start the
#'     service
#'   \item On Windows: Download from
#'     \url{https://github.com/dmajkic/redis/downloads} and double click
#'     'redis-server.exe'
#' }
#' }
#' }
#' @examples
#' # ----------------------Basic Usage ----------------------
#'
#' # Define a path to your queue.
#' queue <- qs_queue(path = tempfile())
#'
#' # Reset
#' queue$reset()
#'
#' # Check if the queue is corrupted.
#' queue$validate()
#'
#' # You have not pushed any messages yet.
#' # Let's say two parallel processes (A and B) are sharing this queue.
#' # Process A sends Process B some messages.
#' # You can only send character vectors.
#' queue$list()
#'
#' # Start push
#' # Push a normal message
#' queue$push(value = 'Do this', message = 'hello')
#'
#' # Push a quo
#' v <- 16
#' queue$push(value = rlang::quo({
#'   sqrt(!!v)
#' }), message = 'eval')
#'
#' # Push a large object
#' queue$push(value = rnorm(100000), message = 'sum')
#'
#' # Push only message
#' queue$push(value = NULL, message = 'stop')
#'
#' # Check queued messages.
#' # The `time` is a formatted character string from `Sys.time()`
#' # indicating when the message was pushed. `key` is unique key
#' # generated from `time`, `value` and queue internal `ID`
#' queue$list()
#'
#' # Number of messages in the queue.
#' queue$count
#'
#' # Number of messages that were ever queued.
#' queue$total
#'
#' # Return and remove the first messages that were added.
#' queue$pop(2)
#'
#' # Number of messages in the queue.
#' queue$count
#'
#' # List what's left
#' queue$list()
#'
#' val1 <- queue$pop()
#' val2 <- queue$pop()
#'
#' # Destroy the queue's files altogether.
#' queue$destroy()
#'
#' \dontrun{
#'   # Once destroyed, validate will raise error
#'   queue$validate()
#' }
#' # ----------------------Cross-Process Usage ----------------------
#'
#' # Cross session example
#'
#' queue <- text_queue()
#'
#' # In another process
#' future::future({
#'   process_pid = Sys.getpid()
#'   queue$push(process_pid)
#' }) -> f
#'
#' # In current process, get pid
#' # wait 0.2 seconds, making sure the queue has at least an item
#' Sys.sleep(0.2)
#' message = queue$pop()
#' message[[1]]
#'
#' # ----------------------Shiny Example ----------------------
#' library(shiny)
#' library(promises)
#' library(dipsaus)
#'
#' ui <- fluidPage(
#'   fluidRow(
#'     column(
#'       12,
#'       actionButtonStyled('do', 'Launch Process', type = 'primary'),
#'       hr(),
#'       textOutput('text')
#'     )
#'   )
#' )
#' server <- function(input, output, session) {
#'   make_forked_clusters()
#'   env = environment()
#'   progress = NULL
#'   queue <- rds_queue()
#'   timer = reactiveTimer(50)
#'   local_data = reactiveValues(text = '')
#'   observe({
#'     timer()
#'     message = queue$pop()
#'     if(length(message)){
#'       instruction = message[[1]]$value
#'       eval_dirty(instruction, env = env)
#'     }
#'   })
#'
#'   output$text <- renderText({
#'     print(local_data$text)
#'     return(local_data$text)
#'   })
#'
#'   observeEvent(input$do, {
#'     updateActionButtonStyled(session, 'do', disabled = TRUE)
#'     if(!is.null(progress)){
#'       progress$close()
#'     }
#'     progress <<- progress2('Analysis [A]', max = 10)
#'
#'     future::future({
#'       lapply(1:10, function(ii){
#'         queue$push(rlang::quo(
#'           progress$inc(!!sprintf('Processing %d', ii))
#'         ))
#'         Sys.sleep(0.2)
#'       })
#'       return(Sys.getpid())
#'     }) %...>% (function(v){
#'       queue$push(rlang::quo({
#'         progress$close()
#'         updateActionButtonStyled(session, 'do', disabled = FALSE)
#'       }))
#'       queue$push(rlang::quo({
#'         local_data$text = !!sprintf('Finished in process (PID): %s', v)
#'       }))
#'     })
#'     NULL
#'   }, ignoreInit = TRUE)
#'
#'   session$onSessionEnded(function(){
#'     queue$destroy()
#'   })
#' }
#'
#' if( interactive() ){
#'   shinyApp(ui, server)
#' }
#'
NULL

#' @rdname queue
#' @param map a \code{fastmap::fastmap()} list
#' @export
session_queue <- function(map = fastmap::fastmap()){
  SessionQueue$new(map = map)
}

#' @rdname queue
#' @param path directory path where queue data should be stored
#' @export
rds_queue <- function(path = tempfile()){
  FileQueue$new(path = path)
}

#' @rdname queue
#' @export
text_queue <- function(path = tempfile()){
  TextQueue$new(path = path)
}

#' @rdname queue
#' @export
qs_queue <- function(path = tempfile()){
  QsQueue$new(path = path)
}

#' @rdname queue
#' @param name character, queue name. If queue name are the same, the data
#' will be shared.
#' @export
redis_queue <- function(name = rand_string()){
  RedisQueue$new(queue_id = name)
}

