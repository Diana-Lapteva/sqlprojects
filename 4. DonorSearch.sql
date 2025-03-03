-- Задачи проекта: Проект направлен на анализ активности доноров, включая изучение регионов с наибольшим числом регистраций, 
-- динамику донаций, влияние бонусов, вовлечение через соцсети, сравнение активности однократных и повторных доноров, 
-- а также оценку эффективности планирования донатов.

-- 1. Определение регионов с наибольшим количеством зарегистрированных доноров

SELECT region,
       COUNT(id) AS donor_count
FROM donorsearch.user_anon_data
GROUP BY region
ORDER BY donor_count DESC
LIMIT 5;


-- region                               | donor_count
-- -------------------------------------|-------------
--                                      | 100574
-- Россия, Москва                       | 37819
-- Россия, Санкт-Петербург              | 13137
-- Россия, Татарстан, Казань            | 6610
-- Украина, Киевская область, Киев      | 3541

-- В топе находятся крупные города, однако также много донаций без места 

-- 2. Динамика общего количества донаций в месяц за 2022 и 2023 годы. 

SELECT DATE_TRUNC('month', donation_date) AS month,
       COUNT(id) AS donation_count
FROM donorsearch.donation_anon
WHERE donation_date BETWEEN '2022-01-01' AND '2023-12-31'
GROUP BY month
ORDER BY month;
    
-- month          | donation_count 
-- ---------------|----------------
-- 2022-01-01     |           1977
-- 2022-02-01     |           2109
-- 2022-03-01     |           3002
-- ..............................................

-- В 2022 году наблюдается устойчивый рост активности доноров.
-- В 2023 году наблюдается спад активности доноров к концу года.
-- В оба года наблюдаются пики активности в весенние месяцы март и апрель.


-- 3. Наиболее активные доноры

SELECT id,
       confirmed_donations
FROM donorsearch.user_anon_data
ORDER BY confirmed_donations DESC
LIMIT 10;

-- id     | confirmed_donations 
-- -------|---------------------
-- 235391 | 361
-- 273317 | 257
-- 211970 | 236
-- и так далее...

-- У донора с ID 235391 большое количество донаций (361).
-- Эти доноры могут быть основой для создания программ лояльности и награждения для вовлечения новых доноров.


-- 4. Влияние бонусной системы

SELECT CASE 
           WHEN COALESCE(b.user_bonus_count, 0) > 0 THEN 'Получили бонусы'
           ELSE 'Не получали бонусы'
       END AS статус_бонусов,
       COUNT(u.id) AS количество_доноров,
       AVG(u.confirmed_donations) AS среднее_количество_донаций
FROM donorsearch.user_anon_data u
LEFT JOIN donorsearch.user_anon_bonus b ON u.id = b.user_id
GROUP BY статус_бонусов;

-- статус_бонусов     | количество_доноров | среднее_количество_донаций 
-- -------------------|--------------------|----------------------------
-- Получили бонусы    | 21108              | 13.90
-- Не получали бонусы | 256491             | 0.53


-- Доноры, которые получили бонусы, в среднем делают значительно больше донаций (~13.90), чем те, кто не получил бонусы (~0.53).
-- Всего 21108 доноров получили бонусы, что значительно меньше по сравнению с общей базой доноров (256491).

-- 5. Вовлечение новых доноров через социальные сети. (Совершили хотя бы одну донацию и каналы через которые пришли)

SELECT CASE
           WHEN autho_vk THEN 'ВКонтакте'
           WHEN autho_ok THEN 'Одноклассники'
           WHEN autho_tg THEN 'Telegram'
           WHEN autho_yandex THEN 'Яндекс'
           WHEN autho_google THEN 'Google'
           ELSE 'Без авторизации через соцсети'
       END AS социальная_сеть,
       COUNT(id) AS количество_доноров,
       AVG(confirmed_donations) AS среднее_количество_донаций
FROM donorsearch.user_anon_data
GROUP BY социальная_сеть;

-- социальная_сеть        | количество_доноров | среднее_количество_донаций 
-- -----------------------|--------------------|----------------------------
-- Google                 | 14292              | 1.08
-- Telegram               | 481                | 1.17
-- ВКонтакте              | 127254             | 0.91
-- и так далее...


-- Доноры, авторизованные через Яндекс, показывают наибольшее среднее количество подтверждённых донаций (~1.73), что указывает на высокую степень вовлечённости.
-- Google и ВКонтакте имеют среднюю активность доноров (~1.08 и ~0.91 соответственно), при этом ВКонтакте является крупнейшей группой по количеству доноров.
-- Одноклассники имеют наименьшее среднее количество подтверждённых донаций (~0.56), что указывает на меньшую вовлечённость доноров, авторизованных через эту сеть.
-- Доноры, не использующие социальные сети для авторизации, показывают низкий уровень активности (~0.71).

-- 6. Сравнение активности однократных доноров со средней активностью повторных доноров.

WITH donor_activity AS (
  SELECT user_id,
         COUNT(*) AS total_donations,
         (MAX(donation_date) - MIN(donation_date)) AS activity_duration_days,
         (MAX(donation_date) - MIN(donation_date)) / (COUNT(*) - 1) AS avg_days_between_donations,
         EXTRACT(YEAR FROM MIN(donation_date)) AS first_donation_year,
         EXTRACT(YEAR FROM AGE(CURRENT_DATE, MIN(donation_date))) AS years_since_first_donation
  FROM donorsearch.donation_anon
  GROUP BY user_id
  HAVING COUNT(*) > 1
)
SELECT first_donation_year,
       CASE 
           WHEN total_donations BETWEEN 2 AND 3 THEN '2-3 донации'
           WHEN total_donations BETWEEN 4 AND 5 THEN '4-5 донаций'
           ELSE '6 и более донаций'
       END AS donation_frequency_group,
       COUNT(user_id) AS donor_count,
       AVG(total_donations) AS avg_donations_per_donor,
       AVG(activity_duration_days) AS avg_activity_duration_days,
       AVG(avg_days_between_donations) AS avg_days_between_donations,
       AVG(years_since_first_donation) AS avg_years_since_first_donation
FROM donor_activity
GROUP BY first_donation_year, donation_frequency_group
ORDER BY first_donation_year, donation_frequency_group;
 
-- 201	6 и более донаций	1	26	663670	26546	1823
-- 207	6 и более донаций	1	37	661775	18382	1817
-- 208	6 и более донаций	1	7	660907	110151	1816
-- 214	6 и более донаций	1	39	658841	17337	1809
-- 1900	6 и более донаций	1	7	45136	7522	124

-- В данных обнаружены аномалии: длительные периоды активности доноров (до 1800 лет) и большие промежутки между донациями.
-- Это свидетельствует о наличии ошибок в данных, особенно в части корректности указания дат донаций. 
-- Доноры демонстрируют большую вовлечённость и остаются активными в течение длительного времени. 
-- Повторные доноры — ключевая аудитория. Они совершают большее количество донаций,
-- что требует внимательного анализа и создания программ удержания.

-- Задача 7. Ализировать планирования доноров и их реальной активности

WITH planned_donations AS (
  SELECT user_id, donation_date, donation_type
  FROM donorsearch.donation_plan
),
actual_donations AS (
  SELECT user_id, donation_date
  FROM donorsearch.donation_anon
),
planned_vs_actual AS (
  SELECT
    pd.user_id,
    pd.donation_date AS planned_date,
    pd.donation_type,
    COALESCE(ad.user_id, NULL) AS actual_user
  FROM planned_donations pd
  LEFT JOIN actual_donations ad 
    ON pd.user_id = ad.user_id AND pd.donation_date = ad.donation_date
)
SELECT
  donation_type,
  COUNT(*) AS total_planned_donations,
  COUNT(actual_user) AS completed_donations,
  ROUND(COUNT(actual_user) * 100.0 / COUNT(*), 2) AS completion_rate
FROM planned_vs_actual
GROUP BY donation_type;


    
-- |donation_type|total_planned_donations|completed_donations|completion_rate|
-- |-------------|-----------------------|-------------------|---------------|
-- |Безвозмездно |          22903        |        4950       |      21.61    |
-- |Платно       |          3299         |        429        |      13.00    |

-- Процент выполнения планов донаций низок для обоих типов доноров: 21.61% для безвозмездных и 13.00% для платных.

-- Рекомендации:

-- Для доноров, которые не получают бонусы, следует разработать стратегии по мотивации, такие как внедрение бонусной системы. 
-- Для повторных доноров следует разрабатывать специальные программы лояльности и удержания.
-- Активнее использовать платформы Яндекс и Telegram для привлечения доноров, а также разработать стратегии для повышения вовлечённости через Одноклассники.
-- Провести очистку и верификацию данных, чтобы избежать искажений в анализах и результатах.