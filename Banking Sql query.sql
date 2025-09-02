create database Bank;
use Bank;
select * from account_details;

select * from Cust_basicinfo;
select * from product_Engagement;
select * from Productdetails;
SELECT COUNT(*) AS total_rows from annual_income;
#1)Extract the customers based on their segment Imperia,preferred,Classic,bottom tier

select * from(
select p.Customer_ID,p.Total_income,pe.Q4_Avg_Balance,a.NPA, case when 
(p.Total_income>=500000 and pe.Q4_Avg_Balance>=500000 and  a.NPA='No') then 'Imperia'
when (p.Total_income>=150000 and pe.Q4_Avg_Balance>=200000 and  a.NPA='No') then 'Preferred'
when (a.NPA='Yes') then 'Bottom tier' when(p.Total_income<100000 or pe.Q4_Avg_Balance<5000 )
then 'Bottom tier' else 'Classic' end as customer_Category
from product_engagement as pe join productdetails as p on p.Customer_ID=pe.Customer_ID
join account_details as a on a.Customer_ID=p.Customer_ID)t  where t.customer_Category='Imperia';


##2.Extract cust_id based on RFM Segmentation 
update product_engagement set Last_Login_Date='1900-01-01'
where Last_Login_Date='Non-digital User';
alter table product_engagement modify Last_Login_Date date;

SET @ReferenceDate = '2025-04-01';
alter table product_engagement add Recency int;
update product_engagement set Recency=case when Last_Login_Date='1900-01-01' then
case when Q4_Tx_Count>=25 then 5
when Q4_Tx_Count>=10 then 4
when Q4_Tx_Count>=5 then 3
when Q4_Tx_Count>=1 then 2
else 1 
end 
else 
case when datediff(@ReferenceDate,Last_Login_Date)<=15 then 5
when datediff(@ReferenceDate,Last_Login_Date)<=30 then  case when (Q4_Online_Login>0 or Q4_Tx_Count>0) then 5 else 4 end
when datediff(@ReferenceDate,Last_Login_Date)<=60 then  case when (Q4_Online_Login>0 or Q4_Tx_Count>0) then 4 else 3 end
when datediff(@ReferenceDate,Last_Login_Date)<=120 then  case when (Q4_Online_Login>0 or Q4_Tx_Count>0) then 3 else 2 end
when datediff(@ReferenceDate,Last_Login_Date)<=180 then  case when (Q4_Online_Login>0 or Q4_Tx_Count>0) then 2 else 1 end

else 1
end
end ;
select Recency,Customer_ID from product_engagement where Recency=5;
select count(Recency) from product_engagement where Recency=5;

#3)Creating Frequency
SET @ReferenceDate = '2025-04-01';
ALTER TABLE product_engagement ADD COLUMN Cust_ID_Num INT;
UPDATE product_engagement
SET Cust_ID_Num = CAST(SUBSTRING(Customer_ID, 5) AS UNSIGNED);
alter table product_engagement add Activity_score int;
update product_engagement set  Activity_score=(Q1_Tx_Count+Q2_Tx_Count+Q3_Tx_Count+Q4_Tx_Count)+
(Q1_Online_Login+Q2_Online_Login+Q3_Online_Login+Q4_Online_Login);
alter table cust_basicinfo modify Customer_Since date;
ALTER TABLE cust_basicinfo ADD COLUMN cust_duration INT;
UPDATE cust_basicinfo
SET cust_duration = TIMESTAMPDIFF(YEAR, Customer_Since, '2025-04-01');


alter table product_engagement add Frequency int;
update product_engagement as pe join cust_basicinfo as cb 
on pe.Customer_ID=cb.Customer_ID 
set pe.Frequency=round((case when pe.Activity_score>400 then 5
when pe.Activity_score>350 then 4
when pe.Activity_score>300 then 3
when pe.Activity_score>200 then 2
else 1 end *0.7)
+ (case WHEN cb.cust_duration >= 8 THEN 5
          WHEN cb.cust_duration >= 6 THEN 4
          WHEN cb.cust_duration >= 4 THEN 3
          WHEN cb.cust_duration >= 1 THEN 2
else 1
end *0.3) 
,0)WHERE pe.Cust_ID_Num BETWEEN 1 AND 5000;
#Not able to update due to lack of system requirements




#4)Cross selling Opportunities Extraction
# Extract all the customer data who have low balance in high income segment
select * from(
select a.Annual_income,p.Q4_Avg_Balance,
case when a.Annual_income>=2000000 and p.Q4_Avg_Balance<200000 then 'Highincome_lowbal'
else 'Not flagged' end as Liability_opportunity 
from product_engagement as p join annual_income as a on p.Customer_ID=a.Customer_ID)t
where t.Liability_opportunity='Highincome_lowbal';
#5)Opportunity for leveraging family network
select sum(Family_members) from cust_basicinfo;

#6)Extract the customers who have savings account and the occupation business
select Customer_ID,Account_Type,Occupation from account_details
where Account_Type in ('savings','Overdraft') and Occupation='Business';

#7)Non Digital users
select Customer_ID from product_engagement
where Last_Login_Date='1900-01-01';

#8)New to Bank selling opportunities
select * from cust_basicinfo where cust_duration <=1;
#credit card sales opportunities
select Customer_ID,Credit_card_Active from productdetails where Credit_card_Active='No';

#9)TOP 10 Q4 Liability customers
select * from (select Customer_ID,Q4_Avg_Balance,dense_rank() 
over(order by Q4_Avg_Balance desc)as Liability_rank
from product_engagement )t where Liability_rank between 1 and 10;

#10)NPA Customers
select Customer_ID,NPA from account_details
where NPA='Yes';

#11)The customers who raised high number of complaints and each reason seperately.
select * from(select Customer_ID,Complaint_Reason,Total_CRM_Complaints,
dense_rank() over( partition by Complaint_Reason order by Total_CRM_Complaints desc)CRM_Comprank
from account_details )t where CRM_Comprank=2 and Complaint_Reason='Fraud';


#12)Suspicious Transaction
select a.Annual_Income,p.Customer_ID
from product_engagement as p join annual_income
as a on a.Customer_ID=p.Customer_ID
where (a.Annual_Income<500000) and 
(p.Q1_Tx_Amount+p.Q2_Tx_Amount+p.Q3_Tx_Amount+p.Q4_Tx_Amount)>= 5000000;


#13)Loan defaulters
select Housing_Loan_Payment_Status,count(*) as tot_defaulters
from productdetails where Housing_Loan_Payment_Status='Late'
group by Housing_Loan_Payment_Status;


