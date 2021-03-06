% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/strings.R
\name{col2hexStr}
\alias{col2hexStr}
\title{Convert color to Hex string}
\usage{
col2hexStr(col, alpha = NULL, prefix = "#", ...)
}
\arguments{
\item{col}{character or integer indicating color}

\item{alpha}{\code{NULL} or numeric, transparency. See \code{grDevices::rgb}}

\item{prefix}{character, default is \code{"#"}}

\item{...}{passing to  \code{\link[grDevices]{adjustcolor}}}
}
\value{
characters containing the hex value of each color. See details
}
\description{
Convert color to Hex string
}
\details{
\code{col2hexStr} converts colors such as 1, 2, 3, "red", "blue", ... into
hex strings that can be easily recognized by `HTML`, `CSS` and `JavaScript`.
Internally this function uses \code{\link[grDevices]{adjustcolor}} with two differences:
\enumerate{
\item the returned hex string does not contain alpha value if \code{alpha} is \code{NULL};
\item the leading prefix "#" can be customized
}
}
\examples{

col2hexStr(1, prefix = '0x')      # "0x000000"
col2hexStr('blue')                # "#0000FF"

# Change default palette, see "grDevices::colors()"
grDevices::palette(c('orange3', 'skyblue1'))
col2hexStr(1)                     # Instead of #000000, #CD8500

}
\seealso{
\code{\link[grDevices]{adjustcolor}}
}
