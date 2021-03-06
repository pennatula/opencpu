#We can use this when Rook is not available
#Some notes: 
# - currently multipart POST is not supported
# - there is a bug in rhttpd when doing POST/PUT with body content-length:0
rhttpdhandler <- function(rootpath){
  #load opencpu configuration
  loadconfigs(preload=TRUE);
  
  #handler  
  function(reqpath, reqquery, reqbody, reqheaders){
    
    #get headers
    contenttype <- grep("Content-Type:", strsplit(rawToChar(reqheaders), "\n")[[1]], ignore.case=TRUE, value=TRUE);
    accept <- grep("Accept:", strsplit(rawToChar(reqheaders), "\n")[[1]], ignore.case=TRUE, value=TRUE);
    accept <- sub("^accept: ?", "", accept, ignore.case=TRUE)
    
    #process POST request body
    if(!is.null(reqbody)){
      MYRAW <- list(
        body = reqbody,
        ctype = contenttype
      );
    } else {
      MYRAW <- NULL;
    }
    
    #fix for missing method in old versions of R
    METHOD <- grep("Request-Method:", strsplit(rawToChar(reqheaders), "\n")[[1]], ignore.case=TRUE, value=TRUE);
    METHOD <- sub("Request-Method: ?", "", METHOD, ignore.case=TRUE);
    if(!length(METHOD)){
      METHOD <- ifelse(is.null(reqbody), "GET", "POST");
    }
    
    #collect data from Rook
    REQDATA <- list(
      METHOD = METHOD,
      PATH_INFO = gsub(rootpath, "", reqpath),
      MOUNT = rootpath,
      FULLMOUNT = paste0(sub("/$", "", Sys.getenv("RSTUDIO_HTTP_REFERER")), rootpath),
      GET = reqquery,
      RAW = MYRAW,
      CTYPE = contenttype,
      ACCEPT = accept
    );  
    
    #call method
    response <- serve(REQDATA);
    
    #build DynamicHelp output
    contenttype <- response$headers[["Content-Type"]];
    response$headers["Content-Type"] <- NULL;
    
    #start rhttpd only in rstudio server
    if(nchar(Sys.getenv("RSTUDIO_HTTP_REFERER"))){
      response$headers["X-ocpu-server"] <- "rhelp/rstudio";        
    } else {
      response$headers["X-ocpu-server"] <- "rhelp/rhttpd";      
    }
    
    #sort headers
    #response$headers <- response$headers[order(names(response$headers))];  
    
    list(
      "payload" = readBin(response$body, "raw", file.info(response$body)$size),
      "content-type" = contenttype,
      "headers" = paste(names(response$headers), ": ", response$headers, sep=""),
      "status code" = response$status
    );
  }
}
