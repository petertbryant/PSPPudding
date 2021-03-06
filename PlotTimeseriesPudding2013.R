#This script should: Point to data source.  Format data. Create a   Compare data to standard. Graph the timeseries.
#Pudding spring and summer and fall 2013
#Julia Crown April 2014
####

####This function is two years old and based in Dan's python world.  Simplify me!
get.cases <- function(chk.values) {
  ## Checks for non-numeric values in the vector "chk.values", which should
  ## be a character vector. A data.frame is returned with the non-numeric
  ## values (cases) and the number of occurrences for each case. If there
  ## are olnly numeric values in the input vectore, the entries in the 
  ## data.frame returned are "No non-numeric values found" for the case
  ## and NA for the count
  ## Created by Kevin Brannan
  ## Version 1.0.0.09.20.2012
  tmp.cases <- chk.values[grep("[^0-9.]",chk.values)][!duplicated(chk.values[grep("[^0-9.]",chk.values)])]
  if(length(tmp.cases) > 0){
    tmp.cases.report <- data.frame(Case = tmp.cases,Count=as.numeric(NA))
    for(ii in 1:length(tmp.cases)){
      tmp.cases.report$Count[ii] <- length(grep(tmp.cases.report$Case[ii],chk.values))
    }
  } else{
    tmp.cases.report <- data.frame("No non-numeric values found",NA)
    names(tmp.cases.report) <- c("Case","Count")
  }
  return(tmp.cases.report)
}

## load package for ODBC
library(RODBC)
## connect to element and get data
channel <- odbcConnect("element")
## get the names of all the tables in the database
TableNames<- sqlTables(channel,errors = FALSE)
## test query
tmp.test <- sqlFetch(channel, "dbo.Repo_Result", stringsAsFactors=FALSE, max=20)

#Pudding PSP stations 2013 
station.list <- c(10000, 11516, 31875, 10646, 10917)

#Build the query
myQuery <- c()
for (i in 1:length(station.list)) {
  qry <- paste0("SELECT * FROM dbo.Repo_Result WHERE  Station_ID ='",station.list[i],"'  AND Client LIKE '%Pesticide%' AND Project LIKE '%Pudding%' AND (Work_Order LIKE '%130%' OR Work_Order LIKE '%131%') ")
  myQuery <- append(myQuery, qry)
}

## Retrieve data.
for(i in 1:length(myQuery)) {
  print(myQuery[i])
  data <- sqlQuery(channel,myQuery[i],stringsAsFactors = FALSE, na.strings = "NA")
  ifelse(i==1,mydata <- data, mydata <- rbind(mydata,data))
  rm(data)
}

unique(mydata$Work_Order)

library(stringr)
#inpath <-"\\\\Deqhq1\\PSP\\Pudding\\2013Pudding\\"
#infile <- "Copy of Pudding FINAL Summer-Fall Spring2013.csv"
#mydata.raw <- read.csv(paste(inpath, infile, sep = ""), colClasses = "character")
#mydata <- mydata.raw
Analyte <- mydata$OrigAnalyte
Station_Description <- mydata$Station_Description
Station_Number <- as.numeric(mydata$Station_ID)
outpath.plot.points <- ("\\\\Deqhq1\\PSP\\Pudding\\2013Pudding\\")
setwd(outpath.plot.points)

RESULT <- str_trim(mydata$Result)
report <- get.cases(RESULT)
report


####To the report above, add a column called "Sub" and populate with substituted values. This is the value that will be substituted.
####Also, create a column called "RESULT_clean".  Populate column with the substituted values.
####Check the report$Sub for unacceptable substitutions.  MANUAL clean up with final values.
report$Sub <- gsub("[^0-9.]","",report$Case)
report$SubFinal  <- report$Sub #Create a copy of the Sub field
RESULT_clean <- gsub("[^0-9.]","",RESULT)

#report[report$Case == '-0.1','SubFinal'] <- -0.1
#mydata[mydata$RESULT == '-0.1','Result_clean'] <- -0.1
#View(mydata[mydata$RESULT == '-0.1',])

####turns empty fields into NAs.
report$SubFinal <- as.numeric(report$SubFinal) 
RESULT_clean <- as.numeric(RESULT_clean) 
report

####convert dates from characters to dates
#date <- as.Date(strptime(mydata$Sampled, format="%d-%b-%y %H:%M:%s")) #still lost the hours/minutes
date <- as.Date(strptime(mydata$Sampled_Date, format="%d %b %Y")) 

####Create new table with only wanted columns
mydata_clean <- data.frame(Station_Number, Station_Description, date, Analyte, RESULT, mydata$Units, mydata$SampleType, RESULT_clean, "RESULT_clean.ug.l"=NA, "RESULT_clean.ug.l.subND"=NA, stringsAsFactors = FALSE)
mydata_clean$RESULT_clean.ug.l <- as.numeric(mydata_clean$RESULT_clean.ug.l)
mydata_clean$RESULT_clean.ug.l.subND <- as.numeric(mydata_clean$RESULT_clean.ug.l.subND)

####Subset and set aside the field duplicates ----
unique(mydata_clean$mydata.SampleType) 

FD <- subset(mydata_clean, mydata.SampleType %in% c("Field Duplicate", "Field Duplicate::FD") & RESULT_clean != "NA") #dataframe of all detected FDs
unique(FD$RESULT_clean)

####Make new subset without the Voids, Field Dupes and Blanks.
sort(unique(mydata_clean$RESULT)) #verify that the names in quotes are the names being used in the datatable
mydata_clean <- subset(mydata_clean, RESULT != "Void" & RESULT != "Cancelled")
unique(mydata_clean$mydata.SampleType) #verify that the names in quotes are the names being used in the datatable
mydata_clean <- subset(mydata_clean, Station_Number != 10000)
mydata_clean <- subset(mydata_clean, mydata.SampleType != "Field Duplicate")
mydata_clean <- subset(mydata_clean, mydata.SampleType != "Field Duplicate::FD")

####Find out which field duplicates are larger than the field primaries. Make a table
df <- NULL
df.fp <- NULL
for(i in 1:nrow(FD)){
  FD2 <- FD[i,]
  FP <- subset(mydata_clean, Analyte == FD$Analyte[i] & date == FD$date[i] & Station_Number == FD$Station_Number[i] & mydata.SampleType %in% c("Field Primary", "Field Primary::FP")) #find the matching field primary
  if(nrow(FP) > 1) print("more than one match") #check that getting one match only
  FP.result <- FP$RESULT_clean #get just the number
  if(is.na(FP.result) == TRUE){
    df <- rbind(df, FD2)    
    df.fp <- rbind(df.fp, FP)
  }else{  
    if(FD$RESULT_clean[i] > FP.result){
      df <- rbind(df, FD2)
      df.fp <- rbind(df.fp, FP)
    }
  }
}


####Remove Field Primaries that are less than Field Duplicates
index <- row.names(df.fp) #row.names of the field primaries in order
for(aa in index){
  mydata_clean[as.character(aa),] <- NA #NA out the field primaries
}
mydata_clean <- subset(mydata_clean, is.na(Station_Number) == FALSE)

####Add Field Duplicates that are more than Field Primaries
mydata_clean <- rbind(df,mydata_clean)


####Subset out not needed data
station.list <- unique(mydata_clean$Station_Number) #list of stations
unique(mydata_clean$Analyte) #list of lab analytes
#Deleting the weird [2C] tag from ELEMENT
mydata_clean$Analyte <- gsub(" \\[2C\\]$","",mydata_clean$Analyte)

detections <- subset(mydata_clean, RESULT != "ND" ) #subset out the NDs 
#detections <- subset(mydata_clean, is.na(RESULT_clean) == FALSE ) #subset out the NDs 
analytes <- unique(detections$Analyte) #list of detected analytes
analytes
####obtain the sampling dates
sort(unique(mydata_clean$date))

####Establish Benchmarks and Exceedances

#### pre-processing minimum criteria with Excel for now:----
criteria.file <- "Pesticide Benchmarks and Criteria_Feb 04 2014.csv"
criteria <- read.csv(file=paste0("\\\\Deqhq1\\PSP\\Rscripts\\Wasco\\Wasco2013\\", criteria.file), row.names=1, colClasses = "character")

min.DEQ.criteria <- criteria$min.AL.DEQ.WQS
min.EPA.criteria <- criteria$min.AL.EPA.benchmark
min.criteria <- data.frame(criteria$Pollutant, min.DEQ.criteria, min.EPA.criteria, criteria$minimum.criteria.benchmark.value, stringsAsFactors = FALSE)

#matching the analytes name with the min.criteria name----
#recursive until Has.min.criteria is all TRUE 
criteria.pollutant.list <- unique(min.criteria$criteria.Pollutant)
Has.min.criteria <- analytes %in% criteria.pollutant.list #Caution!!"analytes" comes from the detections subset only - so NOT all the available criteria will be populated into later datasets!! It WILL skip mismatched (between LEAD analyte name and criteria name) nondetects!!
check <- data.frame(Has.min.criteria, analytes)
check  #no minimum criteria/benchmarks exist for Total Solids or DEET or Pronamide 
#end recursion
min.criteria[criteria$Pollutant == '2,6-Dichlorobenzamide (BAM)','criteria.Pollutant'] <- "2,6-Dichlorobenzamide" #example for substitutions (first is old name in criteria list, second is new analyte name)
min.criteria[criteria$Pollutant == '4,4`-DDD','criteria.Pollutant'] <- "4,4´-DDD" #example for substitutions (first is old name in criteria list, second is new analyte name)
min.criteria[criteria$Pollutant == '4,4`-DDE','criteria.Pollutant'] <- "4,4´-DDE" #example for substitutions (first is old name in criteria list, second is new analyte name)
#change min.criteria table - replace criteria value for 2,4-D with 2,4-D acids and salts
aaa <- as.numeric(min.criteria[min.criteria$criteria.Pollutant == "2,4-D acids and salts",'criteria.minimum.criteria.benchmark.value'])#benchmark for 2,4-D acids and salts
min.criteria[criteria$Pollutant == '2,4-D','criteria.minimum.criteria.benchmark.value'] <- aaa 
#delete repeated imidacloprid
min.criteria <- min.criteria[-(382), ]

####duplicate dataset.
mydata_clean_noV <- mydata_clean

####fill out ug/L column----
unique(mydata_clean_noV$mydata.Units)
#[1] "ng/L" "mg/L" "µg/L"

for(i in 1:nrow(mydata_clean_noV)){
  if(mydata_clean_noV$mydata.Units[i] == "mg/L"){ 
    mydata_clean_noV$RESULT_clean.ug.l[i] <- mydata_clean_noV$RESULT_clean[i]*1000 #mg to ug
  } else {
    if(mydata_clean_noV$mydata.Units[i] == "ng/L"){
      mydata_clean_noV$RESULT_clean.ug.l[i] <- mydata_clean_noV$RESULT_clean[i]/1000 #ng to ug
    } else {
      if(mydata_clean_noV$mydata.Units[i] == "µg/L"){
        mydata_clean_noV$RESULT_clean.ug.l[i] <- mydata_clean_noV$RESULT_clean[i] #µg to ug
      } else {
            mydata_clean_noV$RESULT_clean.ug.l[i] <- NA #some other units
      }
    }
  }
}

####Substitute the NDs for zeroes in a new column
for(i in 1:nrow(mydata_clean_noV)){
  if(mydata_clean_noV$RESULT[i] == "ND"){
    mydata_clean_noV$RESULT_clean.ug.l.subND[i] <- 0  
  }else{
    if(mydata_clean_noV$RESULT[i] !="ND"){
      mydata_clean_noV$RESULT_clean.ug.l.subND[i] <- mydata_clean_noV$RESULT_clean.ug.l[i]
    }
  }
}

####Determine minimum benchmark exceedances
for(i in 1:nrow(mydata_clean_noV)){
  ccc <- mydata_clean_noV$Analyte[i]
  ddd <- match(ccc, min.criteria$criteria.Pollutant)
  mydata_clean_noV$benchmark.DEQ[i] <- as.numeric(min.criteria$min.DEQ.criteria[ddd])   #make a column of appropriate benchmark
  mydata_clean_noV$benchmark.EPA[i] <- as.numeric(min.criteria$min.EPA.criteria[ddd])   #make a column of appropriate benchmark  
  mydata_clean_noV$benchmark[i] <- as.numeric(min.criteria$criteria.minimum.criteria.benchmark.value[ddd])   #make a column of appropriate benchmark
  mydata_clean_noV$final_digress[i] <- ifelse(mydata_clean_noV$RESULT_clean.ug.l[i] > mydata_clean_noV$benchmark[i], 1,0) #make column with digression stations (T/F)
}
digressions <- (mydata_clean_noV[is.na(mydata_clean_noV$final_digress) == FALSE & mydata_clean_noV$final_digress == 1,])
digressions

#### Determine percent digression of criteria
mydata_clean_noV$percent.benchmark <- mydata_clean_noV$RESULT_clean.ug.l/mydata_clean_noV$benchmark
mydata_clean_noV$exceed.type <- NA
  
for(i in 1:nrow(mydata_clean_noV)){
  if(is.na(mydata_clean_noV$RESULT_clean[i]) == FALSE & is.na(mydata_clean_noV$benchmark[i]) == TRUE){ #result is a detection AND benchmark does NOT exist
    mydata_clean_noV$exceed.type[i] <- "no benchmark available"
  }else{
    if(is.na(mydata_clean_noV$percent.benchmark[i])==FALSE){ #percent.benchmark is a real number
      if(mydata_clean_noV$percent.benchmark[i] < 0.1){
      mydata_clean_noV$exceed.type[i] <- "less than ten percent of benchmark"  
    }else{
      if(mydata_clean_noV$percent.benchmark[i] >= 0.1 & mydata_clean_noV$percent.benchmark[i] < 0.5){
        mydata_clean_noV$exceed.type[i] <- "between ten and fifty percent of benchmark"
      }else{
        if(mydata_clean_noV$percent.benchmark[i] >= 0.5 & mydata_clean_noV$percent.benchmark[i] < 1.0){
          mydata_clean_noV$exceed.type[i] <- "between fifty and 100 percent of benchmark"
        }else{
          if(mydata_clean_noV$percent.benchmark[i] > 1.0){
            mydata_clean_noV$exceed.type[i] <- "greater than 100 percent of benchmark"
            }
          }
        }
      }
    }
  }
}
####check that these analytes truly do NOT have a benchmark value
aaa <- (mydata_clean_noV[mydata_clean_noV$exceed.type == "no benchmark available",])
unique(aaa$Analyte) #confirmed, no criteria for TS, and DEET, BAM, pronamide, 44DDD, 44DDE, chlorpropham, acetamiprid
#changed criteria for 2,4-D

rm(mydata)

detections <- subset(mydata_clean_noV, is.na(RESULT_clean) == FALSE) #subset out the NDs 

####Output a summary table 
Det.freq.table <- data.frame("Station"=NA, "Station.Description"=NA, "Parameter"=NA,"Average"=NA, "Max"=NA, "criteria"=NA, "ALR"=NA, "N Samples" = NA, "percent.det.freq"=NA, "exceed.type"=NA, stringsAsFactors=FALSE)

####Four
for(ii in analytes){
  subset.points0 <- subset(mydata_clean_noV, Analyte == ii)#aaa
  tot.n <- nrow(subset.points0)#bbb
  for(i in station.list){
    subset.points <- subset(subset.points0, Station_Number == i)#ccc
    if(length(subset.points$RESULT_clean)>0){
      
      detects.n <- nrow(subset(subset.points, is.na(RESULT_clean) == FALSE))
      type.n <- nrow(subset.points)#ddd
      percent.det.freq <- (detects.n/type.n)*100
      
      Station <- min(subset.points$Station_Number)
      Station.Description <- min(subset.points$Station_Description)
      Analyte <- min(subset.points$Analyte)
      Average <- mean(subset.points$RESULT_clean.ug.l.subND)
      Max <- max(subset.points$RESULT_clean.ug.l.subND)
      matchup <- match(Analyte, min.criteria$criteria.Pollutant)
      criteria <- as.numeric(min.criteria$criteria.minimum.criteria.benchmark.value[matchup])
      ALR <- Max/criteria
      
      df1 <- data.frame("Station"=Station, "Station.Description"=Station.Description, "Parameter"=Analyte,"Average"=Average, "Max"=Max, "criteria"=criteria, "ALR"="Not Calculated", "N Samples" = type.n, "percent.det.freq"=percent.det.freq, "exceed.type"="Not Calculated", stringsAsFactors=FALSE)
      Det.freq.table <- rbind(df1, Det.freq.table)
    }
  }
}

####Two and Three
#Aggregate Basin wide statistics
ii <- "Hexazinone"
for(ii in analytes){
  subset.points <- subset(mydata_clean_noV, Analyte == ii)
  if(length(subset.points$RESULT_clean)>0){
    
    tot.n <- nrow(subset.points)
    detects <- subset(subset.points, is.na(exceed.type) == FALSE)
    det.n <- nrow(detects)
    percent.det.freq <- (det.n/tot.n)*100
    
    Station <- "Basin aggregate"
    Station.Description <- "Basin aggregate"
    Analyte <- min(subset.points$Analyte)
    Average <- mean(subset.points$RESULT_clean.ug.l.subND)
    Max <- max(subset.points$RESULT_clean.ug.l.subND)
    matchup <- match(Analyte, min.criteria$criteria.Pollutant)
    criteria <- as.numeric(min.criteria$criteria.minimum.criteria.benchmark.value[matchup])
    ALR <- Max/criteria
    
    df1 <- data.frame("Station"=Station, "Station.Description"=Station.Description, "Parameter"=Analyte,"Average"=Average, "Max"=Max, "criteria"=criteria, "ALR"=ALR, "N Samples" = tot.n, "percent.det.freq"=percent.det.freq, "exceed.type"="Total Detection Freq", stringsAsFactors=FALSE)
    Det.freq.table <- rbind(df1, Det.freq.table)
  }
}

####One
for(ii in analytes){
  subset.points0 <- subset(mydata_clean_noV, Analyte == ii)#aaa
  n.tot <- nrow(subset.points0)#bbb
  for(iii in unique(mydata_clean_noV$exceed.type)){
    subset.points <- subset(subset.points0, exceed.type == iii)#ccc
    if(length(subset.points$RESULT_clean)>0){
      
      n.exceed.type <- nrow(subset.points)#ddd
      percent.det.freq <- (n.exceed.type/n.tot)*100
      
      Station <- min(subset.points$Station_Number)
      Station.Description <- min(subset.points$Station_Description)
      Analyte <- min(subset.points$Analyte)
      Average <- mean(subset.points$RESULT_clean.ug.l.subND)
      Max <- max(subset.points$RESULT_clean.ug.l.subND)
      matchup <- match(Analyte, min.criteria$criteria.Pollutant)
      criteria <- as.numeric(min.criteria$criteria.minimum.criteria.benchmark.value[matchup])
      ALR <- Max/criteria
      
      df1 <- data.frame("Station"="Basin aggregate", "Station.Description"="Basin aggregate", "Parameter"=Analyte,"Average"=Average, "Max"=Max, "criteria"=criteria, "ALR"="Not Calculated", "N Samples" = n.exceed.type, "percent.det.freq"=percent.det.freq, "exceed.type"=iii, stringsAsFactors=FALSE)
      Det.freq.table <- rbind(df1, Det.freq.table)
    }
  }
}

#Det.freq.table <- subset(Det.freq.table, percent.det.freq>0) #subset for parameters with detections
write.csv(Det.freq.table, paste(outpath.plot.points,"Pudding_2013_detection_frequencies.csv",sep="")) 

write.csv(mydata_clean_noV, paste(outpath.plot.points,"Pudding_2013_mydata_clean_noV.csv",sep="")) 


####
####loop through analyte list and graph multiple stations

xicides <- analytes
ii <- "2,4-D"



for(ii in analytes){
  subset.points <- subset(detections, Analyte == ii)
  col.v <- c("cyan4","coral4", "darkolivegreen4", "darkorchid4", "darkgoldenrod4")
  pch.v <- c(seq(15, 18), 4, seq(19, 25), seq(1, 3), seq(5,14))
  
  if(length(subset.points$RESULT_clean)>0){
    x.min <- min(subset.points$date) #min of subset date
    x.max <- max(subset.points$date) #max of subset date
    x.lim <- c("2013/03/25", "2013/11/20")
    x.lim <- if(length(subset.points$RESULT_clean) >= 1){
      as.Date(x.lim, "%Y/%m/%d")  
    }else{
      c(x.min, x.max) ####define the data domain for graph
    }
    y.min <- 0
    y.max <- max(subset.points$RESULT_clean.ug.l) #max of data for graph
    #     if(ii == "Chlorpyrifos") y.max <- 0.083 #exception to accomodate chlorpyrifos secondary WQS
    y.lim <- c(y.min,y.max + (1.*y.max)) ####define the data range ####change head space here
    # y.lim <- c(y.min,y.max + (.1*y.max)) ####define the data range ####head space is very small for these analytes <- c("Acifluorfen", "2,4-D", "Diuron", "MCPA", "MCPP", "Sulfometuron-methyl")
    x.lab <- "2013"
    y.lab <- paste0(ii, " (ug/L)")
    title <- paste0("")
    file.name.ts <- paste0("Group_", ii, "_timeseries.png")
    
    png(filename=file.name.ts ,width = 700, height = 400) ####create a png with the station name in the filepath specified above
    par(xpd=NA,oma=c(0,0,4,0), mar=c(5.1,4.1,1.1,2.1)) 
    plot(subset.points$date, subset.points$RESULT_clean.ug.l, pch=NA, xlim=x.lim, ylim=y.lim, xlab=x.lab, ylab=y.lab, cex.axis=1.5, cex.lab=1.5, bty="L", log=log.scale) ####plot the outline of the points  
    
    numeric.criterion.DEQ <- as.numeric(min.criteria[min.criteria$criteria.Pollutant == ii,'min.DEQ.criteria'])
    numeric.criterion.EPA <- as.numeric(min.criteria[min.criteria$criteria.Pollutant == ii,'min.EPA.criteria'])
    if(ii == "2,4-D") numeric.criterion.EPA  <- 13.1
    
    for(p in 1:(length(station.list))){
      subset.points.i <- subset(subset.points, Station_Number == station.list[p])
      points(subset.points.i$date, subset.points.i$RESULT_clean.ug.l, col=col.v[p], pch=pch.v[p], cex=1.8)
      #exceeds.points.i <- subset.points.i[subset.points.i$final_digress == 1,]   
      #points(exceeds.points.i$date, exceeds.points.i$RESULT_clean.ug.l, col="red", bg="red", pch=pch.v[p], cex=1.8) ####plot the exceedances
    }
    
    
    #     if(length(numeric.criterion.DEQ) < 0 || is.na(numeric.criterion.DEQ) == FALSE){
    #       next
    #     }else{
    
    
    #draw DEQ line
    if(length(numeric.criterion.DEQ) > 0){
      if(is.na(numeric.criterion.DEQ) == FALSE){
        lines(x=x.lim, y=c(numeric.criterion.DEQ, numeric.criterion.DEQ), lty=2)#draw WQS
        DEQ.ex <- 999
      }
    } 
    
    
    #draw EPA line (except chlorpyrifos)
    if(ii == "Chlorpyrifos"){
      lines(x=x.lim, y=c(0.083, 0.083), lty=3)#draw Acute Chlorpyrifos WQS (only graph with two WQS)
    }else{
      if(length(numeric.criterion.EPA) > 0){
        if(is.na(numeric.criterion.EPA) == FALSE){
          lines(x=x.lim, y=c(numeric.criterion.EPA, numeric.criterion.EPA), lty=4)#draw WQS 
          EPA.ex <- 1
        }
      }
    } 
    
    
    
    title(main=title, cex.main=1.2, outer=TRUE)

#     ###legend for displaying on charts
#        legend("topright", 
#                  legend=unique(detections$Station_Description), 
#                  col=col.v, 
#                  pch=pch.v, 
#                  xjust=0, yjust=0, box.lty=0, cex=1.2, pt.cex=1.8, horiz=FALSE, 
#           )
    dev.off() ####write the .png
  }else{print(paste0("non-detect_", ii))}
}



##################################################################################
#########

##################################################################################

##################################################################################

####For each station, graph all analytes
#detections0 <- subset(detections, Station_Number == 36179)

herbicides <- c("Atrazine", "Desethylatrazine", "Deisopropylatrazine", "Sulfometuron-methyl", "Pendimethalin", "Diuron", "Simazine", "Metolachlor", "Dichlobenil", "2,6-Dichlorobenzamide", "2,4-D", "Imazapyr", "Hexazinone", "Metribuzin", "Dicamba", "Dimethenamid", "Fluridone", "Trifluralin", "Chlorpropham", "Prometon", "Bromacil", "Triclopyr", "Acetochlor", "Oxyfluorfen", "Napropamide", "Pronamide", "Norflurazon", "Terbacil", "EPTC")


insecticides <- c( "Carbaryl", "Imidacloprid", "Carbofuran", "Chlorpyrifos", "Ethoprop", "Methomyl", "Oxamyl", "Acetamiprid", "Dimethoate", "Diazinon", "Methiocarb", "4,4´-DDD", "4,4´-DDE")


fungicides <- c("Propiconazole", "Pyraclostrobin")

wood.preservative <- "Pentachlorophenol"
PCP <- "DEET"

xicides <- fungicides     

i <- 32068
for(i in station.list){
  subset.points <- subset(detections, Station_Number == i)
  subset.points <- subset(subset.points, Analyte != "Total Solids")
  analyte0 <- unique(subset.points$Analyte)
  
#   col.v <- seq(1, 31)
   col.v <- rep("antiquewhite4", 31)
   pch.v <- c(seq(15, 25), seq(1, 14))
#   ddd <- numeric(0)
#   for(ii in analytes){
#     bbb <- subset(subset.points, Analyte == ii)
#     ccc <- length(bbb$Analyte)
#     ddd <- c(ddd, ccc)
#   }
#   pch.v <- numeric(0)
#   for(d in 1:31){
#     aaa <- rep(d, ddd[d])
#     pch.v <- c(pch.v, aaa)
#   }
  
  
  if(length(subset.points$RESULT_clean)>0){
    x.min <- min(subset.points$date) #min of subset date
    x.max <- max(subset.points$date) #max of subset date
    x.lim <- c("2013/03/05", "2013/11/10")
    x.lim <- if(length(subset.points$RESULT_clean) >= 1){
      as.Date(x.lim, "%Y/%m/%d")  
    }else{
      c(x.min, x.max) ####define the data domain for graph
    }
    y.min <- 0
    y.max <- max(subset.points$RESULT_clean.ug.l) #max of data for graph
#    if(ii == "Chlorpyrifos") y.max <- 0.083 #exception to accomodate chlorpyrifos secondary WQS
    y.lim <- c(y.min,y.max + (0.1*y.max)) ####define the data range
    x.lab <- "2013"
    y.lab <- ""
    title <- paste0("Number of analytes", length(analyte0))
    file.name.ts <- paste0(i, "_fungicides", "_timeseries.png")
    
    png(filename=file.name.ts ,width = 700, height = 400) ####create a png with the station name in the filepath specified above
    par(xpd=NA,oma=c(0,0,4,0), mar=c(5.1,4.1,1.1,2.1)) 
    plot(subset.points$date, subset.points$RESULT_clean.ug.l, pch=NA, xlim=x.lim, ylim=y.lim, xlab=x.lab, ylab=y.lab, cex.axis=1.2, cex.lab=1.2, bty="L", log=log.scale) ####plot the outline of the points  
    
    for(p in 1:(length(xicides))){
      subset.points.i <- subset(subset.points, Analyte == xicides[p])
      points(subset.points.i$date, subset.points.i$RESULT_clean.ug.l, col=col.v[p], pch=pch.v[p], cex=1.8)
      exceeds.points.i <- subset.points.i[subset.points.i$final_digress == 1,]   
      points(exceeds.points.i$date, exceeds.points.i$RESULT_clean.ug.l, col="red", bg="red", pch=pch.v[p], cex=1.8) ####plot the exceedances
    }


    #numeric.criterion.DEQ <- as.numeric(min.criteria[min.criteria$criteria.Pollutant == ii,'min.DEQ.criteria'])
    #numeric.criterion.EPA <- as.numeric(min.criteria[min.criteria$criteria.Pollutant == ii,'min.EPA.criteria'])
  
#     for(ii in analytes){
#       subset.points.i <- subset(subset.points, Analyte == ii)
#       points(subset.points.i$date, subset.points.i$RESULT_clean.ug.l, col=col.v, pch=pch.v)
#     }
#     
# ii <- "Bifenthrin"
# ii <- "Chlorpyrifos"
# 
#     for(ii in analytes){
#       if(ii %in% unique(digressions$Analyte)){
#         exceeds.points.i <- subset.points.i[subset.points.i$final_digress == 1,]   
#         points(exceeds.points.i$date, exceeds.points.i$RESULT_clean.ug.l, col="red", bg="red", pch=pch.v) ####plot the exceedances
#       }
#     }


    ####legend for displaying on charts
#        legend("topright", 
#                  legend=xicides, 
#                  col= col.v, 
#                  pch=pch.v, 
#                  ncol=3,
#                  xjust=0, yjust=0, box.lty=0, cex=1.2, pt.cex=1.8, horiz=FALSE, 
#           )
#     
    dev.off() ####write the .png
  }else{print(paste0("non-detect_", ii))}
}
