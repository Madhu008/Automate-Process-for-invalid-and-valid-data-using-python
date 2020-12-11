# Automate-Process-for-invalid-and-valid-data-using-python
Create functionalities to automate the testing of the data as invalid and valid. The data has to be 
read data from .csv files and the results/processes are to be shown as logs. To initialize the log we have 
created config.ini giving the log path and rulebook path - rules to be followed/functionalities (rulebook.csv)

Open config file and provide log file creation path and RULEBOOK path
Fill  Rulebook.csv file with proper column number of input files(start from 1 to so on)
For null check and duplicate rule use zero (0) to check all column. 
Use NA if no Rules need to be applied on column.
Use columnno:date format on datecheck column in rulebook
ex 4:dd/mm/yyyy ,5:mm-dd-yyyy
Provide correct valid path for valid and invalid files
Ex. D:\VALID\ ,E:\LOG\VALID\
Run the program
