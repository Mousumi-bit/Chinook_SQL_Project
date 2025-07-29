use chinook;
-- Objective Answers:
-- 1.Does any table have missing values or duplicates? If yes how would you handle it ?
-- check for Nulls:
select 
sum(case when customer_id is null then 1 else 0 end) as null_customer_id,
sum(case when first_name is null then 1 else 0 end) as null_first_name,
sum(case when last_name is null then 1 else 0 end) as null_last_name,
sum(case when company is null then 1 else 0 end) as null_company,
sum(case when address is null then 1 else 0 end) as null_address,
sum(case when city is null then 1 else 0 end) as null_city,
sum(case when state is null then 1 else 0 end) as null_state,
sum(case when country is null then 1 else 0 end) as null_country,
sum(case when postal_code is null then 1 else 0 end) as null_postal_code,
sum(case when phone is null then 1 else 0 end) as null_phone,
sum(case when fax is null then 1 else 0 end) as null_fax,
sum(case when email is null then 1 else 0 end) as null_email,
sum(case when support_rep_id is null then 1 else 0 end) as null_support_rep_id 
from customer;

-- To Replace the null values
set sql_safe_updates=0;
update customer 
set company=coalesce(company,"Not Available"),
state=coalesce(state,"Not Available"),
postal_code=coalesce(postal_code,"N/A"),
phone=coalesce(phone,"Not Available"),
fax=coalesce(fax,"Not Available")
where company is null or state is null or postal_code is null or phone is null or fax is null;

-- Check for Duplicates:
Select customer_id,count(*) from customer group by customer_id having count(*)>1;
-- Remove duplicates using row number
with ranked as 
(select customer_id,first_name,last_name,company,address,city,state,country,postal_code,phone,
fax,email,support_rep_id,row_number() over (partition by customer_id order by customer_id) as rnk 
from customer)
delete from customer where customer_id in 
(select customer_id from ranked where rnk>1);

-- Question no.2
-- Find the top-selling tracks and top artist in the USA and identify their most famous genres.
WITH cte as 
(select t.track_id,t.name as track_name,i.invoice_id,i1.billing_country,a1.name as artist_name,
g.name as genre_name from track t join 
invoice_line i on t.track_id=i.track_id join 
invoice i1 on i.invoice_id=i1.invoice_id join 
album a on t.album_id=a.album_id join 
artist a1 on a.artist_id=a1.artist_id join 
genre g on t.genre_id=g.genre_id where i1.billing_country="USA")

SELECT track_name,artist_name,genre_name,
count(invoice_id) as total_count from cte group by track_name,artist_name,
genre_name order by total_count desc limit 5;

-- Question no.3
-- What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?
-- country wise
select country,count(*) as customer_count from customer group by country order by customer_count desc;
-- country,state and city wise customer count
select country,state,city,count(*) as cust_count from customer 
group by country,state,city order by cust_count desc;

-- Question no.4
-- Calculate the total revenue and number of invoices for each country, state, and city:
select billing_country,billing_state,billing_city,
sum(total) as total_revenue,count(invoice_id) as number_of_invoice from 
invoice group by billing_country,billing_state,billing_city order by billing_country;

-- Question no.5
-- Find the top 5 customers by total revenue in each country
with top_5_cus as
(select customer_id,billing_country,sum(total) as total_revenue,
dense_rank() over(partition by billing_country order by sum(total) desc)  as rnk from invoice 
group by customer_id,billing_country )

select concat(b.first_name,"",b.last_name) as full_name ,billing_country as country,
a.total_revenue from top_5_cus a join customer b on a.customer_id=b.customer_id 
where rnk<=5 order by billing_country;

-- Question no.6
-- Identify the top-selling track for each customer

with track_revenue as 
(select c.customer_id, concat(c.first_name,' ', c.last_name) as full_name,
i1.track_id, t.name as track_name,
sum(i1.unit_price * i1.quantity) as total_revenue
from customer c
join invoice i 
on c.customer_id = i.customer_id
join invoice_line i1
on i.invoice_id = i1.invoice_id
join track t 
on i1.track_id = t.track_id
group by c.customer_id, full_name, i1.track_id, t.name),
ranked_track as 
(select customer_id,full_name,track_id,track_name,total_revenue,
row_number() over(partition by customer_id order by total_revenue desc) as rnk
from track_revenue)
select  full_name,  track_name, total_revenue
from ranked_track
where rnk = 1;

-- Question no.7
-- Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?
-- i.Frequency of Purchases
select c.customer_id,concat(c.first_name,"",c.last_name) as full_name,
count(i.invoice_id) as purchase_count from customer c join
invoice i on c.customer_id=i.customer_id group by c.customer_id,
full_name order by purchase_count desc;


-- ii.average order value per customer
select c.customer_id,concat(c.first_name,"",c.last_name) as full_name,
round(avg(i.total),2) as avg_order_value from customer c join invoice i on
c.customer_id=i.customer_id 
group by customer_id order by avg_order_value desc;

-- iii.Preferred payment method
select billing_country,count(*) as orders_count,
round(avg(total),2) as avg_order_value from invoice 
group by billing_country order by orders_count desc;

-- Question no.8
-- What is the customer churn rate?
with active_cust_count as 
(select date_format(invoice_date,"%Y-%m") as month_year,count(distinct customer_id) as cust_count
from invoice group by date_format(invoice_date,"%Y-%m")),
prev_cust_count as 
(select month_year,cust_count,lag(cust_count) over(order by month_year) as prev_month_cust_count
from active_cust_count),
churned_cust as 
(select month_year,cust_count,prev_month_cust_count,
(prev_month_cust_count-cust_count) as churn_customers from prev_cust_count)

select month_year,cust_count,prev_month_cust_count,churn_customers,
round(churn_customers*100/prev_month_cust_count,2) as churn_rate from churned_cust 
where churn_customers>0;

-- Question no.9
-- Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.
WITH table_join as
(select t.track_id,i.total,i.billing_country,g.name as genre_name,a1.name as artist_name
from track t join invoice_line i1 on t.track_id=i1.track_id
join invoice i on i1.invoice_id=i.invoice_id
join genre g on t.genre_id=g.genre_id
join album a on a.album_id=t.album_id 
join artist a1 on a.artist_id=a1.artist_id),
genre_sale as
(select genre_name,sum(total) as genre_sales from table_join 
group by genre_name),
USA_genre as 
(select genre_name,sum(total) as usa_sale from table_join where 
billing_country="USA"  GROUP BY genre_name),
USA_artist_sale AS 
(select artist_name,genre_name,sum(total) as artist_usa_sale,
rank() over(partition by genre_name order by sum(total) desc) as genre_rnk
from table_join where billing_country="USA" GROUP BY artist_name,genre_name)

select a.genre_name,c.artist_name,a.genre_sales,round(b.usa_sale *100/a.genre_sales,2) as 
USA_sale_per,c.artist_usa_sale from genre_sale a join USA_genre b 
on a.genre_name=b.genre_name join USA_artist_sale c on 
a.genre_name=c.genre_name and c.genre_rnk=1 order by USA_sale_per desc;

-- Question no.10
-- Find customers who have purchased tracks from at least 3 different genres

with overall_data as 
(select t.track_id,i.customer_id,g.name as genre_name,g.genre_id
from track t join invoice_line i1 on t.track_id=i1.track_id
join invoice i on i1.invoice_id=i.invoice_id 
join genre g on t.genre_id=g.genre_id)

select  b.customer_id,concat(b.first_name,"",b.last_name) as full_name,
count(distinct a.genre_id) as genre_count from 
overall_data a join customer b on a.customer_id=b.customer_id 
group by customer_id,full_name having count(distinct genre_id)>=3 order by genre_count desc;

-- Question no.11
-- Rank genres based on their sales performance in the USA

select g.name as genre_name ,sum(i.total) as total_sale_amount,
dense_rank() over( order by sum(i1.unit_price*i1.quantity) desc ) as genre_rank
from track t join invoice_line i1 on t.track_id=i1.track_id
join invoice i on i.invoice_id=i1.invoice_id
join genre g on g.genre_id=t.genre_id where i.billing_country="USA"
GROUP BY g.name;

-- Question no.12
-- Identify customers who have not made a purchase in the last 3 months

with last_purchase_day as 
(select customer_id,max(invoice_date) as last_purchase_date from 
invoice group by customer_id)
select l.customer_id,concat(c.first_name,"",c.last_name) as full_name,
date(l.last_purchase_date) from last_purchase_day l join customer c 
on c.customer_id=l.customer_id 
where l.last_purchase_date<date_sub(curdate(),interval 3 month)
order by date(l.last_purchase_date) desc;

-- Subjective Answers

-- Question no.1
-- Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.
with all_table as 
(select i.billing_country,t.track_id,t.album_id,t.genre_id,g.name as genre_name,
a.title as album_name,a1.name as artist_name , i.total as total_sale 
from track t join invoice_line i1 on i1.track_id=t.track_id 
join invoice i on i1.invoice_id = i.invoice_id
join genre g on g.genre_id=t.genre_id 
join album a on a.album_id=t.album_id 
join artist a1 on a1.artist_id=a.artist_id where i.billing_country="USA"),
genre_sales as
(select sum(total_sale) as genre_sale,genre_name
from all_table group by genre_name order by genre_sale desc limit 3),
album_sale as 
(select album_name,artist_name,genre_name,sum(total_sale) as album_sale from all_table
 group by album_name,artist_name,genre_name),
 ranked  as 
 (select a.genre_name,a.artist_name,a.album_name,a.album_sale,b.genre_sale,
 rank() over( order by a.album_sale desc) as rnk 
 from genre_sales b join album_sale a on a.genre_name=b.genre_name)
 
 select genre_name,artist_name,album_name,album_sale from ranked 
 where rnk<=3;
 
 -- Question no.2
 -- Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.

with combine_table as 
(select i.billing_country,t.track_id,t.genre_id,g.name as genre_name, i.total as total_sale 
from track t join invoice_line i1 on i1.track_id=t.track_id 
join invoice i on i1.invoice_id = i.invoice_id
join genre g on g.genre_id=t.genre_id 
 where i.billing_country!="USA"),
genre_sales as
 (select genre_name,billing_country,sum(total_sale) as genre_sale from combine_table 
 group by genre_name,billing_country),
 rnk_genre as 
 (select genre_name,billing_country,genre_sale,
 dense_rank() over(partition by billing_country order by genre_sale desc) as rnk
 from genre_sales )
 
 select genre_name,billing_country,genre_sale from rnk_genre where rnk=1 order by
 billing_country,rnk desc;
 
 -- Question no.3
 -- Customer Purchasing Behavior Analysis: How do the purchasing habits 
 -- (frequency, basket size, spending amount) of long-term customers differ from
 -- those of new customers? 
 -- What insights can these patterns provide about customer loyalty and retention strategies?

-- step 1 first_purchase_date_per_customer
with first_purchase as 
(select c.customer_id,min(date(i.invoice_date)) as first_purchase_date 
from customer c join invoice i on c.customer_id=i.customer_id group by c.customer_id),

-- step 2 classify new  and long_term_customer
customer_classify as 
(select customer_id,case when first_purchase_date>=
"2020-10-01" then "New"
else "Long_Term" end as customer_type from first_purchase),

-- step 3. calculate frequency,basket_size,total_spending by each customer
Customers_purchase as 
(select c.customer_id,concat(c.first_name,"",c.last_name) as customer_name,
count(distinct i.invoice_id) as purchase_frequency,
sum(i1.quantity) as total_item,
sum(i.total) as total_spending,
round(sum(i.total)/count(distinct i.invoice_id),2) as avg_spending_per_purchase
from customer c join invoice i on i.customer_id=c.customer_id
join invoice_line i1 on i1.invoice_id=i.invoice_id group by 
c.customer_id,customer_name),
overall_data as 
(select a.customer_name,b.customer_type,a.purchase_frequency,a.total_item,
a.total_spending,a.avg_spending_per_purchase from customers_purchase a 
join customer_classify b on a.customer_id=b.customer_id)

select customer_type,round(avg(purchase_frequency),2) as avg_frequency,
round(avg(total_item),2) as avg_basket_size,round(avg(total_spending),2) as avg_total_spending,
round(avg(avg_spending_per_purchase),2) as avg_spend_per_purchase
from overall_data group by customer_type;

-- Question no.4
-- Product Affinity Analysis: Which music genres, artists,
-- or albums are frequently purchased together by customers? 

-- step 1 genre affinity analysis

WITH invoice_genres AS (
  SELECT i.invoice_id,g.name AS genre_name FROM invoice i
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN genre g ON t.genre_id = g.genre_id GROUP BY i.invoice_id, g.name),
  
genre_pairs AS (
  SELECT a.invoice_id,a.genre_name AS genre1,b.genre_name AS genre2
  FROM invoice_genres a JOIN invoice_genres b ON a.invoice_id = b.invoice_id 
  AND a.genre_name < b.genre_name)
  
SELECT genre1, genre2, COUNT(*) AS times_bought_together
FROM genre_pairs GROUP BY genre1, genre2 ORDER BY times_bought_together DESC LIMIT 20;

-- step 2  artists affinity analysis

WITH invoice_artists AS (
  SELECT i.invoice_id,a1.name AS artist_name FROM invoice i
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id JOIN album a ON a.album_id=t.album_id
  join artist a1 on a.artist_id=a1.artist_id GROUP BY i.invoice_id, a1.name),
  
artist_pairs AS (
  SELECT a.invoice_id,a.artist_name AS artist1,b.artist_name AS artist2 FROM invoice_artists a
  JOIN invoice_artists b ON a.invoice_id = b.invoice_id AND a.artist_name < b.artist_name)
  
SELECT artist1, artist2, COUNT(*) AS times_bought_together
FROM artist_pairs GROUP BY artist1, artist2
ORDER BY times_bought_together DESC LIMIT 20;

-- step 3  albums affinity analysis

WITH invoice_albums AS (
  SELECT i.invoice_id,a.title AS album_name FROM invoice i
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id JOIN album a ON a.album_id=t.album_id
  GROUP BY i.invoice_id, a.title),
  
album_pairs AS (
  SELECT a.invoice_id,a.album_name AS album1,b.album_name AS album2 FROM invoice_albums a
  JOIN invoice_albums b ON a.invoice_id = b.invoice_id AND a.album_name < b.album_name)
  
SELECT album1, album2, COUNT(*) AS times_bought_together
FROM album_pairs GROUP BY album1, album2 ORDER BY times_bought_together DESC LIMIT 20;

-- Question no.5
-- Regional Market Analysis: Do customer purchasing behaviors 
-- and churn rates vary across different geographic regions or store locations? 

select c.country, count(distinct c.customer_id) as cust_count,
count(i.invoice_id) as purchase_frequency,sum(i.total) as total_spend,
sum(i1.quantity) as total_quantity,round(sum(i1.quantity)/count(i.invoice_id),2) as 
avg_basket_size,round(sum(i.total)/count(i.invoice_id),2) as avg_spend_per_purchase
from customer c join invoice i on i.customer_id=c.customer_id
join invoice_line i1 on i1.invoice_id=i.invoice_id group by c.country;

-- churn_rate by country
SELECT c.country, COUNT(*) AS total_customers,
  SUM(CASE 
        WHEN i.last_purchase_date < DATE_SUB('2020-12-30', INTERVAL 6 MONTH) 
        THEN 1 ELSE 0 
      END) AS churned_customers,
  ROUND(SUM(CASE 
        WHEN i.last_purchase_date < DATE_SUB('2020-12-30', INTERVAL 6 MONTH) 
        THEN 1 ELSE 0 
      END) / COUNT(*) * 100, 2) AS churn_rate_percent
FROM (
  SELECT customer_id, MAX(invoice_date) AS last_purchase_date
  FROM invoice
  GROUP BY customer_id) i
JOIN customer c ON i.customer_id = c.customer_id
GROUP BY c.country
ORDER BY churn_rate_percent DESC;

-- Question no.6
-- Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history),
--  which customer segments are more likely to churn or pose a higher risk of reduced spending?

with purchase_gap as (
 SELECT c.customer_id,c.country,c.city,i.invoice_id,i.invoice_date, i.total,
LAG(i.invoice_date) OVER(PARTITION BY c.customer_id ORDER BY i.invoice_date) AS prev_purchase_date
   FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id),
 customer_segment as 
(SELECT customer_id,country,city,
    DATEDIFF(MAX(invoice_date), MAX(prev_purchase_date)) AS purchase_gap,
    COUNT(invoice_id) AS purchase_count,
    SUM(total) AS total_spend FROM purchase_gap GROUP BY customer_id, country, city),
 risk_profile as  
(SELECT customer_id,country,city,purchase_gap,purchase_count,total_spend,
  CASE WHEN purchase_gap > 60 THEN 'High_risk'
    WHEN purchase_gap BETWEEN 30 AND 60 THEN 'Moderate'ELSE 'Low'
  END AS risk_category FROM customer_segment)
  select risk_category,count(customer_id) as customer_count,
  avg(total_spend) as avg_spending,avg(purchase_count) as avg_purchase_count
  from risk_profile group by risk_category order by risk_category ;

-- Question no.7
-- Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) 
-- to predict the lifetime value of different customer segments?

WITH customer_tenure AS (
    SELECT c.customer_id,CONCAT(c.first_name, " ", c.last_name) AS full_name,
DATE(MIN(i.invoice_date)) AS first_purchase_date,DATE(MAX(i.invoice_date)) AS last_purchase_date,
ROUND(DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) / 30) AS tenure_months,
COUNT(i.invoice_id) AS purchase_count, SUM(i.total) AS total_spent,
ROUND(SUM(i.total) / COUNT(i.invoice_id), 2) AS avg_purchase_value FROM customer c 
    JOIN invoice i ON i.customer_id = c.customer_id GROUP BY c.customer_id, full_name),
clv AS (
    SELECT customer_id,first_purchase_date,last_purchase_date,tenure_months,purchase_count,
	total_spent,avg_purchase_value,ROUND(avg_purchase_value * 
	(CASE WHEN tenure_months = 0 THEN purchase_count ELSE purchase_count / tenure_months 
		END) * tenure_months, 2) AS CLV,CASE 
            WHEN last_purchase_date < DATE_SUB('2020-12-31', INTERVAL 6 MONTH) THEN 'Churned'
            ELSE 'Active' END AS cust_status FROM customer_tenure)
SELECT cust_status,COUNT(customer_id) AS count_customer,ROUND(AVG(total_spent), 2) AS avg_total_spent,
    ROUND(AVG(avg_purchase_value), 2) AS avg_purchase_value,ROUND(AVG(CLV), 2) AS avg_clv
FROM clv GROUP BY cust_status ORDER BY cust_status;


-- Question no.10
-- How can you alter the "Albums" table to add a new column named "ReleaseYear" of 
-- type INTEGER to store the release year of each album?

 
 -- alter table album add column ReleaseYear int;

-- Question no.11
-- Answer
  with customer_data as 
 (select c.customer_id,c.country,
 sum(i.total) as total_revenue,count(t.track_id) as track_count 
 from customer c join invoice i on i.customer_id=c.customer_id
join invoice_line i1  on i.invoice_id=i1.invoice_id 
 join track t on t.track_id=i1.track_id group by c.customer_id,c.country)

 select country,count(customer_id) as customer_count,
round(avg(total_revenue),2) as avg_spend,round(avg(track_count),2) as avg_track_purchase from 
 customer_data group by country order by customer_count desc;







