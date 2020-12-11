### ===========================================================================================================================
### Project Name    : demo.py
### Description     : Create functionalities to automate the testing of the data as invalid and valid. The data has to be 
###                   read from .csv files and the results/processes are to be shown as logs. To initialize the log we have
###                   created config_demo.ini giving the log path and rulebook path - rules to be followed/functionalities (rulebook.csv)
###                   Functionalities >
### OS              : Windows
### Author          : Madhusudan Deshmukh
### Date            : 20-10-2020 
### ===========================================================================================================================

### ===========================================================================================================================
### === Imports === 
import pandas as pd
import numpy as np
import re
from time import time
from datetime import datetime
from configparser import ConfigParser
import os

### ===========================================================================================================================

### ===========================================================================================================================
### === Functions ===
# creating log file with current Date and Time
def create_log_file():
    current_datetime = datetime.now()

    year = str(current_datetime.year)
    month = str(current_datetime.month)
    day = str(current_datetime.day)
    
    hour = str(current_datetime.hour)
    minute = str(current_datetime.minute)
    sec = str(current_datetime.second)
    microsec = str(current_datetime.microsecond)
    
    return year + "_" + month + "_" + day + "_" + hour + "_" + minute + "_" + sec + "_" + microsec + "_log.txt"

# Reading the configuration file (to get the log file path and rulebook path)
def read_config_file():
    config_obj = ConfigParser()
    config_obj.read("config_demo.ini")
    
    # Get log file location
    log_path = config_obj["LOGFILELOCATION"]["path"]
    rulebook_path = config_obj["RULEBOOK"]["file"]
    
    return log_path, rulebook_path

# check rows and columns in file    
def count_columns(f):
    return f.shape[0], f.shape[1]

# create files in location 
def create_valid_csv(na_free, valid_path, file_name):
    if not os.path.exists(valid_path):
        os.makedirs(valid_path)
    

    if na_free.shape[0] > 0:
        na_free.to_csv(valid_path+file_name, index=False, header=True)

        
# create invalid file 
def create_Invalid_csv(file_name,invalid_path,only_na):
    if only_na.shape[0] > 0:
         
        hdr = False  if os.path.isfile(invalid_path+file_name) else True
        only_na.to_csv(invalid_path+file_name, mode='a', header=hdr,index=False)

    
   
    
    
### ===========================================================================================================================

### ===========================================================================================================================
### === Functionalities ===

### === 1. NULL CHECK ===
def remove_null(df, null_check):
    na_free = None
    only_na = None
    
    if null_check == 0 or null_check is '0':
        na_free = df.dropna()
        #only_na = df[~df.index.isin(na_free)]
        only_na = df[np.invert(df.index.isin(na_free.index))]
        
        
    else:
        null_check = str(null_check)
        null_check = null_check.split(',')
        for i in null_check:
            na_free = df.dropna(subset=[df.columns[int(i)-1]], axis=0)
            only_na = df[np.invert(df.index.isin(na_free.index))]
            #only_na = df[~df.index.isin(na_free.index)]
    
    only_na = only_na.assign(Reason = "Null check Failed")
    
    return na_free, only_na
    
### === 2. DUPLICATE ===
def duplicate_check(na_free, dup_check):
    dd= na_free
    if dup_check == 0 or dup_check is '0':
        na_free = na_free.drop_duplicates()
        only_na = dd[np.invert(dd.index.isin(na_free.index))]
    else:
        dup_check = str(dup_check)
        dup_check = dup_check.split(',')
        for i in dup_check:
            na_free = na_free.drop_duplicates(subset= [dd.columns[int(i)-1]], keep= 'first', inplace=False)
            #only_na = df[~df.index.isin(na_free.index)]
            only_na = dd[np.invert(dd.index.isin(na_free.index))]
    
            
    only_na = only_na.assign(Reason = "This row  contain duplicate value")
    return na_free,only_na

### === 3. INTEGER CHECK ===
def integer_check(na_free, int_check):
    dd= na_free
  
    int_check = str(int_check)
    int_check = int_check.split(",")
    for i in int_check:
        na_free = na_free[na_free[na_free.columns[int(i)-1]].apply(lambda x: x .isdigit())]
        only_na = dd[np.invert(dd.index.isin(na_free.index))]
  
    only_na = only_na.assign(Reason = "Integer Check failed")
    
    return na_free, only_na

### === 4. CHARACTER CHECK ===
def character_check(na_free, char_check):
    dd= na_free
    char_check = str(char_check)
    char_check = char_check.split(",")
    for i in char_check:
        na_free = na_free[na_free[na_free.columns[int(i)-1]].apply(lambda x: x .isalpha())]
        only_na = dd[np.invert(dd.index.isin(na_free.index))]
   
    only_na = only_na.assign(reason = "Character check Failed")
    
    return na_free, only_na

### === 5. EMAIL VALIDATION ===
def email_validation(na_free, email_check):
    dd= na_free
      
    email_check = str(email_check)
    email_check = email_check.split(",")
    
    pattern = re.compile(r"(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$)")
    
    for i in email_check:
        na_free = na_free[na_free[na_free.columns[int(i)-1]].apply(lambda x: True if pattern.match(x) else False)]
        only_na = dd[np.invert(dd.index.isin(na_free.index))]
            
    only_na = only_na.assign(reason = "Email check Failed")
    
    return na_free, only_na

### === 6. DATE VALIDATION ===
# dd/mm/yyyy
def date_validation(na_free, date_check,df):
    dd = na_free
    date_check = date_check.split(",")
    
    for i in date_check:
        date_format = i[2:]
        date_column = i[0]
       
        
    
        if date_format == "dd/mm/yyyy" or date_format == "dd-mm-yyyy" : 
                                           
            pattern = re.compile(r"^(?:(?:31(\/|-|\.)(?:0?[13578]|1[02]|(?:Jan|Mar|May|Jul|Aug|Oct|Dec)))\1|(?:(?:29|30)(\/|-|\.)(?:0?[1,3-9]|1[0-2]|(?:Jan|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))\2))(?:(?:1[6-9]|[2-9]\d)?\d{2})$|^(?:29(\/|-|\.)(?:0?2|(?:Feb))\3(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00))))$|^(?:0?[1-9]|1\d|2[0-8])(\/|-|\.)(?:(?:0?[1-9]|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep))|(?:1[0-2]|(?:Oct|Nov|Dec)))\4(?:(?:1[6-9]|[2-9]\d)?\d{2})$")
            na_free =  na_free[ na_free[na_free.columns[int(date_column)-1]].apply(lambda x: True if pattern.match(x) else False)]
            only_na = dd[~dd.index.isin(na_free.index)]
            
        elif date_format == "mm/dd/yyyy" or date_format == "mm-dd-yyyy":        
            
                       
            pattern = re.compile(r"((^(10|12|0?[13578])([/])(3[01]|[12][0-9]|0?[1-9])([/])((1[8-9]\d{2})|([2-9]\d{3}))$)|(^(11|0?[469])([/])(30|[12][0-9]|0?[1-9])([/])((1[8-9]\d{2})|([2-9]\d{3}))$)|(^(0?2)([/])(2[0-8]|1[0-9]|0?[1-9])([/])((1[8-9]\d{2})|([2-9]\d{3}))$)|(^(0?2)([/])(29)([/])([2468][048]00)$)|(^(0?2)([/])(29)([/])([3579][26]00)$)|(^(0?2)([/])(29)([/])([1][89][0][48])$)|(^(0?2)([/])(29)([/])([2-9][0-9][0][48])$)|(^(0?2)([/])(29)([/])([1][89][2468][048])$)|(^(0?2)([/])(29)([/])([2-9][0-9][2468][048])$)|(^(0?2)([/])(29)([/])([1][89][13579][26])$)|(^(0?2)([/])(29)([/])([2-9][0-9][13579][26])$))")
            
            na_free =  na_free[ na_free[na_free.columns[int(date_column)-1]].apply(lambda x: True if pattern.match(x) else False)]
            only_na = dd[~dd.index.isin(na_free.index)]
            
           
                
        elif date_format == "yyyy/mm/dd" or date_format == "yyyy-mm-dd":
            
                      
            pattern = re.compile(r"^\d{4}[\-\/\s]?((((0[13578])|(1[02]))[\-\/\s]?(([0-2][0-9])|(3[01])))|(((0[469])|(11))[\-\/\s]?(([0-2][0-9])|(30)))|(02[\-\/\s]?[0-2][0-9]))$")
            
            na_free =  na_free[ na_free[na_free.columns[int(date_column)-1]].apply(lambda x: True if pattern.match(x) else False)]
            only_na = dd[~dd.index.isin(na_free.index)]
       
        else:
                          
            raise Exception("Date format is not valid")
    
    only_na = only_na.assign(reason = "Date check Failed")

    
    return na_free, only_na
        
### ===========================================================================================================================
### === Main Function ===
def main():
    # Get log path and rulebook path
    log_path, rulebook_path = read_config_file()
    
    # Create and open log file in append mode
    if not os.path.exists(log_path):
        os.makedirs(log_path)
        
    with open(log_path+create_log_file(), "a+") as f:
        f.write(str(datetime.now()) + " ... Code Started ... \n")
        # pd.set_option('display.max_columns', None)            # to display all columns while print statement // Uncomment to print dataframe
        data = pd.read_csv(rulebook_path)
        data.fillna(data.dtypes.replace({'float': 0.0, 'O': 0}), downcast='infer', inplace=True)
        
        for _, row in data.iterrows():
            file_name     =   row["FILE"]
            null_check    =   row["NULL_CHECK"]
            dup_check     =   row["DUPLICATE"]
            int_check     =   row["INTEGER"]
            char_check    =   row["CHARCHECK"]
            email_check   =   row["EMAILCHECK"]
            date_check    =   row["DATECHECK"]
            file_flag     =   row["ACTIVE_FLAG"]
            valid_path    =   row["VALID_PATH"]
            invalid_path  =   row["INVALID_PATH"]
            
           
            if os.path.exists(invalid_path+file_name):
                os.remove(invalid_path+file_name)
                      
            
            
           
            
            try:
                # checking file processed start time
                start = time()
                
                file_flag = file_flag.upper()
                if file_flag == 'Y':
                    
                    df = pd.read_csv(file_name, sep=",",error_bad_lines=False, dtype='unicode')
                    f.write("\n" + str(datetime.now()) + " ... file {0} started reading ... \n".format(file_name))
                    row, _ = count_columns(df)
                elif file_flag == 'N':
                    f.write("\nWARNING: **** No entries in Rulebook file **** \n")
                                                        
                    continue
                else:
                    f.write("\nERROR: **** Incorrect value in active_flag in Rulebook file **** \n")
                    continue
                    
                
                # Run Functionalities >>> Use Try and Except Block
                try:
                    ### === 1. NULL_CHECK ===
                    f.write("\n... Check for nulls in {0} file ...".format(file_name))
                    f.write("\n... {0} rows read from the input file ...".format(row))
                    
                    # Functionality call
                    na_free, only_na = remove_null(df, null_check)
                    
                    create_Invalid_csv(file_name,invalid_path,only_na)
                    
                    # Function call
                    row, _ = count_columns(na_free)
                    
                    f.write("\n... Output row count = {0} after null validation ...".format(row))
                    
                    ### === 2. DUPLICATE ===
                    f.write("\n... Check for duplicates in {0} file ...".format(file_name))
                    f.write("\n... {0} rows read from the input file ...".format(row))
                    
                    # Functionality call
                    na_free,only_na = duplicate_check(na_free,dup_check)
                    create_Invalid_csv(file_name,invalid_path,only_na)
                    
                    # Function call
                    row, _ = count_columns(na_free)
                    
                    f.write("\n... Output row count = {0} after duplicate validation ...".format(row))
                    
                    ### === 3. INTEGER CHECK ===
                    f.write("\n... Check for Integer Column in {0} file ...".format(file_name))
                    f.write("\n... {0} rows read from the input file ...".format(row))
                    
                    # Functionality call
                    if int_check == 0 or int_check is '0':
                        pass
                    else:
                        
                        na_free, only_na = integer_check(na_free, int_check)
                        
                        create_Invalid_csv(file_name,invalid_path,only_na)
                    
                    
                    # Function call
                    row, _ = count_columns(na_free)
                    
                    f.write("\n... Output row count = {0} after Integer Column Validation ...".format(row))
                    
                    ### === 4. CHARACTER CHECK ===
                    f.write("\n... Check for characters Column in {0} file ...".format(file_name))
                    f.write("\n... {0} rows read from the input file ...".format(row))
                    
                    # Functionality Call
                    if char_check == 0 or char_check is '0':
                        pass
                    elif not (char_check == 0 or char_check is '0'):
                        na_free, only_na = character_check(na_free, char_check)
                        
                        create_Invalid_csv(file_name,invalid_path,only_na)
                
                    # function call
                    row, _ = count_columns(na_free)
                    
                    f.write("\n... Output row count = {0} after Character Column Validation ...".format(row))
                    
                    ### === 5. EMAIL VALIDATION ===
                    f.write("\n... Check for Email Column in {0} file ...".format(file_name))
                    f.write("\n... {0} rows read from the input file ...".format(row))
                    
                    # functionality call
                    if email_check == 0 or email_check is '0':
                         pass
                    elif not (email_check == 0 or email_check is '0'):
                        na_free, only_na = email_validation(na_free, email_check)
                        create_Invalid_csv(file_name,invalid_path,only_na)
                        
                    # function call
                    row, _ = count_columns(na_free)
                    
                    f.write("\n... Output row count = {0} after Email Column Validation ...".format(row))
                    
                    ### === 6. DATE VALIDATOR ===
                    # dd/mm/yyyy
                    f.write("\n... Check for Date Format in {0} file ...".format(file_name))
                    f.write("\n... {0} rows read from the input file ...".format(row))
                    
                    # functionality call
                    if  date_check == 0 or date_check is '0':
                          pass
                    elif not (date_check == 0 or date_check is '0'):
                                          
                        na_free, only_na = date_validation(na_free, date_check,df)
                        
                        create_Invalid_csv(file_name,invalid_path,only_na)
                    
                    # function call
                    row, _ = count_columns(na_free)
                    
                    f.write("\n... Output row count = {0} after Date Format Validation ...".format(row))
                                        
                except IndexError:
                    f.write("\nERROR: **** Incorrect Column number in Rulebook file **** \n")
                except ValueError:
                    f.write("\nERROR: **** Incorrect Input Value in Rulebook file **** \n")
                except TypeError:
                    f.write("\nERROR: **** Incorrect Column Value in Rulebook file **** \n")
                except Exception:
                    f.write("\nERROR: **** Incorrect Date format in Rulebook file **** \n")
               
                    
              
                finally:
                    # Create files in location
                    create_valid_csv(na_free, valid_path, file_name)
                    
                    # check file processing time 
                    end = time()
                    t = end - start
                    
                    row, _ = count_columns(na_free)
                   
                    
                    f.write("\n ''' Valid Rows: {0} saved in valid files '''".format(row))
                   
                    f.write("\nSUCCESS: **** file {0} taken {1} secs for processing the data ****\n\n".format(file_name, t))

            except FileNotFoundError:
                print()
                f.write("\nERROR: **** File {0} does not exist ****\n".format(file_name))   

if __name__ == "__main__":
    main()
    print("**** Validation completed successfully **** \n Please check log file for more details !!")
    
