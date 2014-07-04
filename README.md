process
=======

data process script

## Run Envenment  
Script test in Unbuntu14.04 & zsh.  
Script use gnuplot to generate plot, test with gnuplot-v4.6.  
## Concept  
### Plot  
This data process script used to process log file and generate plot in the form of X-Y or X-Y1-Y2.  

Each Y-axis can include multile curve form multile data source.  
Every **Data Source** can be any col in log file or a simple four operations of servel col in log file.   

### File Format
#### Mode  
Multil Mode File would be transtmited to a tmp log file with moutil domin, which each Mode map to a specile domin.  
   
#### Domin  

## Usage
1. usage:./process.sh [-f filename or dirname] [-n size in record] [-t logformat-file]  [-s if set,time would not set to same start]  

2. usage: ./du-process.sh -f 100.log [-b start record number] [-l record number]

