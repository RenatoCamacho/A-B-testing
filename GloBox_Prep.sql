-- create tables
create table users(
				id numeric,
				country varchar,
				gender varchar	
);
create table groups(
				uid numeric,
				"group" varchar,
				join_dt date,
				device varchar
);
create table activity(
				uid numeric,
				dt date,
				device varchar,
				spent numeric
);

/*import values from csv, after saving each page separately as .csv
(after 1st line, replace all ",," with "") | click: tables > Import/Export data */

-- round all SPENT values to 2 decimals
UPDATE activity
SET spent = ROUND(spent::numeric, 2);

-- 1.	Can a user show up more than once in the activity table?
SELECT uid, COUNT(*) AS count
FROM activity
GROUP BY uid
HAVING COUNT(*) > 1
ORDER BY COUNT DESC;

--3.	What SQL function can we use to fill in NULL values? (My example:)
UPDATE users
SET gender = COALESCE(gender, 'Unknown')
WHERE gender IS NULL;

--4.	What are the start and end dates of the experiment?
SELECT MIN(dt), MAX(dt)
FROM activity;

--5.	How many total users were in the experiment?
SELECT COUNT(*) FROM users;

--6.	How many users were in the control and treatment groups?
SELECT "group", COUNT(*)
FROM groups
WHERE "group" IN ('A','B')
GROUP BY "group";

--7.	What was the conversion rate of all users?
SELECT ROUND(100 * COUNT(DISTINCT(a.uid)) * 1.0 / COUNT(DISTINCT(g.uid)),2) || '%' AS conversion_rate
FROM groups g
FULL JOIN activity a USING(uid);

--8.	What was the conversion rate for each group?
SELECT
	ROUND(100 * COUNT(DISTINCT(a.uid)) FILTER (WHERE "group" = 'A') * 1.0 / COUNT(DISTINCT(g.uid))
	FILTER (WHERE "group" = 'A'),2) || '%' AS conversion_A,
	ROUND(100 * COUNT(DISTINCT(a.uid)) FILTER (WHERE "group" = 'B') * 1.0 / COUNT(DISTINCT(g.uid)) 
	FILTER (WHERE "group" = 'B'),2) || '%' AS conversion_B
FROM groups g
FULL JOIN activity a USING(uid);

--9.	What is the average amount spent per user for each group, including users who did not convert?
SELECT
    "group",
    ROUND(AVG(SUM(spent::numeric)) OVER(PARTITION BY "group") / COUNT(DISTINCT g.uid),2) AS avg_spent
FROM groups g
FULL JOIN activity a USING(uid)
GROUP BY "group";
--OR
SELECT groups.group,
ROUND(SUM(activity.spent::numeric) / Count(DISTINCT(groups.uid)),2) As avg_spntA
from groups
left join activity on groups.uid=activity.uid
group by groups.group;

-- create a query for next fase of the project and dowload as CSV
WITH summing AS
	(SELECT DISTINCT(uid),
				  SUM(spent) AS expenditure
FROM activity
GROUP BY uid
HAVING SUM(spent) > 0)

SELECT U.*,
	   g.device,
	   g.group,
	   CASE WHEN expenditure > 0 THEN 1 ELSE 0 END AS converted,
     COALESCE(expenditure, 0.00) AS total_spent	   
FROM users u
LEFT JOIN groups g ON u.id = g.uid
LEFT JOIN summing ON u.id = summing.uid;

-- date query for Novelty vizz in Tableau
SELECT id,
       "group",
       join_dt,
       dt AS conversion_dt,
       dt - join_dt AS days_to_convert,
       COALESCE(a.spent, 0.00) AS spent
FROM users u
RIGHT JOIN activity a ON u.id = a.uid
LEFT JOIN groups g USING(uid)
INNER JOIN (
    SELECT uid, MIN(dt) AS first_purchase_date
    FROM activity
    GROUP BY uid
) subq ON a.uid = subq.uid AND a.dt = subq.first_purchase_date
ORDER BY u.id;