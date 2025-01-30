/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Диана Лаптева
 * Дата: 05.10.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(id) AS total_users,
		SUM(payer) AS active,
		ROUND((SUM(payer)::numeric / COUNT(*)::numeric),4) AS per
FROM fantasy.users;

-- total_users|active|per   |
-- -----------+------+------+
--      22214|  3929|0.1769|
      
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH CTE AS (
    SELECT 
        r.race,
        SUM(u.payer) AS total_paying_players,
        COUNT(u.id) AS total_players
    FROM fantasy.users AS u
    JOIN fantasy.race AS r USING(race_id)
    GROUP BY 
        race
)
SELECT 
    race AS character_race,
    total_players,
    total_paying_players AS paying_players,
    ROUND((total_paying_players::numeric / total_players::numeric),4) AS paying_percentage
FROM CTE
ORDER BY paying_percentage DESC;

-- character_race|total_players|paying_players|paying_percentage|
-- --------------+-------------+--------------+-----------------+
-- Demon         |         1229|           238|           0.1937|
-- Hobbit        |         3648|           659|           0.1806|
-- Human         |         6328|          1114|           0.1760|
-- Orc           |         3619|           636|           0.1757|
-- Northman      |         3562|           626|           0.1757|
-- Angel         |         1327|           229|           0.1726|
-- Elf           |         2501|           427|           0.1707|

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount) AS total_purchases,
		SUM(amount) AS total_amount,
		MIN(amount) AS min_amount,
		MAX(amount) AS max_amount,
		ROUND(AVG(amount)::numeric, 2) AS avg_amount,                                            -- Средняя стоимость покупки
		ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)::numeric, 2) AS median_amount, -- Медиана стоимости покупки
		ROUND(STDDEV(amount)::numeric, 2) AS stddev_amount
FROM fantasy.events 
WHERE amount IS NOT NULL;

-- total_purchases|total_amount|min_amount|max_amount|avg_amount|median_amount|stddev_amount|
-- ---------------+------------+----------+----------+----------+-------------+-------------+
--         1307678|   686615040|       0.0|  486615.1|    525.69|        74.86|      2517.35|
        
-- 2.2: Аномальные нулевые покупки:
SELECT 
    COUNT(CASE WHEN amount = 0 THEN 1 END) AS zero_amount,
    COUNT(amount) AS total,                              
    ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END)::numeric / COUNT(amount), 6) AS count
FROM fantasy.events
WHERE amount IS NOT NULL;

-- zer0_amount|total  |count   |
-- -------+-------+--------+
--     907|1307678|0.000694|
    
   
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

WITH help AS (
    SELECT u.payer,                                      
        u.id AS user_id,                             
        COUNT(e.transaction_id) AS total_tr,   
        COALESCE(SUM(e.amount), 0) AS total_amount    
    FROM fantasy.users AS u
    LEFT JOIN fantasy.events AS e USING(id)             
    WHERE  e.amount IS NOT NULL AND e.amount > 0       
    GROUP BY u.payer, u.id                       
),
aaa AS (
    	SELECT payer,                                          
      	  COUNT(user_id) AS total_users,                  
      	  AVG(total_tr) AS purchases_pu, 
      	  AVG(total_amount) AS amount_pu        
 		FROM help
 		GROUP BY payer
)	
SELECT 
    CASE 
        WHEN payer = 1 THEN 'Paying Players' 
        ELSE 'Non-Paying Players' 
    END AS player_group,                    
    total_users,                            
    ROUND(purchases_pu::numeric, 2),                 
    ROUND(amount_pu::numeric, 2)                    
FROM aaa;

-- player_group      |total_users|round|round   |
-- ------------------+-----------+-----+--------+
-- Non-Paying Players|      11348|97.56|48631.74|
-- Paying Players    |       2444|81.68|55467.74|

-- 2.4: Популярные эпические предметы:


WITH wow AS (
    SELECT e.item_code,                              
        COUNT(e.transaction_id) AS total_sales,   
        COUNT(DISTINCT e.id) AS unique_buyers     
    FROM fantasy.events AS e
    JOIN fantasy.items i ON e.item_code = i.item_code
    WHERE e.amount IS NOT NULL AND e.amount > 0     
    GROUP BY e.item_code                              
),
total_buyers AS (
    SELECT COUNT(DISTINCT e.id) AS total_buyers
    FROM fantasy.events AS e
    WHERE  e.amount IS NOT NULL AND e.amount > 0
)
SELECT i.game_items AS item_name,                                      
    s.total_sales,                                                  
    ROUND(s.total_sales::numeric / SUM(s.total_sales) OVER(), 2) AS sales_d,
    ROUND(s.unique_buyers::numeric / t.total_buyers, 2) AS buyers_d   
FROM wow AS s
JOIN total_buyers AS t ON true                                  
JOIN fantasy.items AS i ON s.item_code = i.item_code                     
ORDER BY buyers_d DESC;                                               

-- Первые 5 строк таблицы:
-- item_name                |total_sales|sales_d|buyers_d|
-- -------------------------+-----------+-------+--------+
-- Book of Legends          |    1004516|   0.77|    0.88|
-- Bag of Holding           |     271875|   0.21|    0.87|
-- Necklace of Wisdom       |      13828|   0.01|    0.12|
-- Gems of Insight          |       3833|   0.00|    0.07|
-- Silver Flask             |        795|   0.00|    0.05|


-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:

WITH race_players AS (
    SELECT u.race_id,                            
        COUNT(u.id) AS total_players          
    FROM fantasy.users AS u
    GROUP BY u.race_id
),
race_buyers AS (
    SELECT u.race_id,                                                           
        COUNT(u.id) AS buying_players,                               
        SUM(u.payer) AS paying_players 
    FROM fantasy.users AS u
    WHERE u.id IN (SELECT DISTINCT id FROM
                   fantasy.events 
                   WHERE amount IS NOT NULL AND amount > 0)
    GROUP BY u.race_id
),
race_activity AS (
    SELECT u.race_id,                                    
        COUNT(e.transaction_id) AS total_purchases,   
        SUM(e.amount) AS total_amount,                
        COUNT(DISTINCT e.id) AS active_players        
    FROM fantasy.users AS u
    JOIN fantasy.events AS e USING(id)           
    WHERE e.amount IS NOT NULL AND e.amount > 0        
    GROUP BY u.race_id
)
SELECT r.race,                                                                      
    rp.total_players,                                                            
    COALESCE(rb.buying_players, 0) AS buying_players,                            
    ROUND(COALESCE(rb.buying_players, 0)::numeric / rp.total_players, 2) AS buying_ratio,  
    ROUND(COALESCE(rb.paying_players, 0)::numeric / rb.buying_players, 2) AS paying_ratio,   
    ROUND(COALESCE(ra.total_purchases::numeric / COALESCE(rb.buying_players, 1), 0), 2) AS avg_purchases_per_player,   
    ROUND(COALESCE(ra.total_amount::numeric / ra.total_purchases, 0), 2) AS avg_amount_per_purchase,                  
    ROUND(COALESCE(ra.total_amount::numeric / COALESCE(rb.buying_players, 1), 0), 2) AS avg_total_amount_per_player    
FROM race_players AS rp
LEFT JOIN race_buyers AS rb USING(race_id)
LEFT JOIN race_activity AS ra USING(race_id)
JOIN fantasy.race AS r USING(race_id)          
ORDER BY avg_total_amount_per_player DESC;

-- race    |total_players|buying_players|buying_ratio|paying_ratio|avg_purchases_per_player|avg_amount_per_purchase|avg_total_amount_per_player|
-- --------+-------------+--------------+------------+------------+------------------------+-----------------------+---------------------------+
-- Northman|         3562|          2229|        0.63|        0.18|                   82.10|                 761.48|                   62519.07|
-- Elf     |         2501|          1543|        0.62|        0.16|                   78.79|                 682.33|                   53761.24|
-- Human   |         6328|          3921|        0.62|        0.18|                  121.40|                 403.07|                   48933.69|
-- Angel   |         1327|           820|        0.62|        0.17|                  106.80|                 455.64|                   48664.63|
-- Hobbit  |         3648|          2266|        0.62|        0.18|                   86.13|                 552.91|                   47621.80|
-- Orc     |         3619|          2276|        0.63|        0.17|                   81.74|                 510.92|                   41761.69|
-- Demon   |         1229|           737|        0.60|        0.20|                   77.87|                 529.02|                   41194.44|

-- Задача 2: Частота покупок

WITH player_intervals AS (
    SELECT e.id AS player_id,                                 
        e.transaction_id,                                  
        TO_DATE(e.date, 'YYYY-MM-DD') AS pur_date,    
        LAG(TO_DATE(e.date, 'YYYY-MM-DD')) OVER (PARTITION BY e.id ORDER BY TO_DATE(e.date, 'YYYY-MM-DD')) AS previous_date,
        u.payer                                             
    FROM fantasy.events AS e
    JOIN fantasy.users AS u USING(id)                      
    WHERE e.amount > 0                                        
),
purchase_days AS (
    SELECT player_id, 
        COUNT(transaction_id) AS total_pur,                                 
        AVG(pur_date - previous_date) AS avg_days,
        payer                                                                      
    FROM player_intervals
    WHERE previous_date IS NOT NULL 
    GROUP BY player_id, payer
), 
active_players AS (
    SELECT 
        player_id, 
        total_pur, 
        avg_days, 
        payer
    FROM purchase_days
    WHERE total_pur >= 25 
), 
ranked_players AS (
    SELECT player_id, 
        total_pur, 
        avg_days, 
        payer, 
        NTILE(3) OVER (ORDER BY avg_days) AS th_group
    FROM active_players
)
SELECT 
    CASE 
        WHEN th_group = 1 THEN 'Высокая частота'
        WHEN th_group = 2 THEN 'Умеренная частота'
        ELSE 'Низкая частота'
    END AS group_name,                                  
    COUNT(player_id) AS total_players,                            
    SUM(payer) AS paying_players,                                 
    ROUND(SUM(payer)::numeric / COUNT(player_id), 2) AS paying_d,         
    ROUND(AVG(total_pur), 2) AS avg_purchases_pp,             
    ROUND(AVG(avg_days), 2) AS avg_days
FROM ranked_players
GROUP BY th_group
ORDER BY th_group;

-- group_name       |total_players|paying_players|paying_d|avg_purchases_pp|avg_days|
-- -----------------+-------------+--------------+--------+----------------+--------+
-- Высокая частота  |         2514|           461|    0.18|          396.90|    3.24|
-- Умеренная частота|         2514|           442|    0.18|           58.95|    7.39|
-- Низкая частота   |         2514|           432|    0.17|           33.66|   12.91|