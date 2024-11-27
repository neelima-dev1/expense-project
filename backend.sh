#!/bin/bash

LOGS_FOLDER="/var/log/expense"
SCRIPT_NAME=$( echo $0 |cut -d "." -f1)
TIME_STAMP=$(date +%Y-%m-%d-%H-%M-%S)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME-$TIME_STAMP.log"
mkdir -p $LOGS_FOLDER

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
CHECK_ROOT(){

if [ $USERID -ne 0 ]
then
    echo -e "$R Please run this script with root privelages $N" | tee -a &>>$LOG_FILE
    exit 1
fi    
}

VALIDATE(){
    if [ $1 -ne 0 ]
    then
    echo -e "$2 is .... $R FAILED $N" | tee -a $LOG_FILE
    exit
    else
        echo -e "$2 is .... $G SUCESS $N" | tee -a $LOG_FILE
    fi    
}

echo "Script Strated executing at: $(date)" | tee -a $LOG_FILE

CHECK_ROOT

dnf module disable nodejs -y &>>$LOG_FILE 
VALIDATE $? "Disable default nodejs"

dnf module enable nodejs:20 -y &>>$LOG_FILE 
VALIDATE $? "Enable nodejs:20"

dnf install nodejs -y &>>$LOG_FILE 
VALIDATE $? "Install nodejs"

id expense &>>$LOG_FILE 
if [ $? -ne 0 ]
then
    echo -e "expense user not exists... $G Creating $N"
    useradd expense &>>$LOG_FILE 
    VALIDATE $? "Creating expense user"
else
    echo -e "expense user already exists... $Y SKIPPING $N"
fi

mkdir -p /app
VALIDATE $? "Creating /app folder"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$LOG_FILE 
VALIDATE $? "Downloading backend application code"

cd /app
rm -rf /app/*  # remove the existing code 
unzip /tmp/backend.zip  &>>$LOG_FILE
VALIDATE $? "Extracting backend application code"

npm install &>>$LOG_FILE
cp /home/ec2-user/expense-project/backend.service /etc/systemd/system/backend.service

# load the data before running backend

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "Installing MYSQL Client"

mysql -h mysql.neelima.online -uroot -pExpenseApp@1 < /app/schema/backend.sql
VALIDATE $? "Schema loading"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Daemon reload"

systemctl enable backend &>>$LOG_FILE
VALIDATE $? "Enabled backend"

systemctl restart backend &>>$LOG_FILE
VALIDATE $? "Restarted Backend"



