CREATE EXTENSION IF NOT EXISTS plpython3u;



CREATE OR REPLACE FUNCTION prodlenie_dash_4.get_table_by_pps_with_budjet(p1 float, p2 float, p3 float, p4 float,
                                                                         p5 float, p6 float,
                                                                         p7 float, p8 float, "startDolg" float,
                                                                         "Target_S" float, "hossposobom" int)

    RETURNS TABLE
            (
                year                                               integer,
                p1                                                 integer,
                p2                                                 integer,
                p3                                                 integer,
                p4                                                 integer,
                p5                                                 integer,
                p6                                                 integer,
                p7                                                 integer,
                p8                                                 integer,
                summa_pp                                           float,
                "startDolg"                                        float,
                "currentDolg"                                      float,
                "current_S"                                        float,
                "Средний срок продления"                           float,
                "Стоимость проведения Вторичных экспертиз"         float,
                "Стоимость проведения Первичных экспертиз"         float,
                "Стоимость проведения ТО/ВТО"                      float,
                "Общая стоимость"                                  float,
                "Долг на следующий год при текущем финансировании" float,
                "Проведено вторичных экспертиз"                    int,
                "Проведено первичных экспертиз"                    int,
                "Всего проведено экспертиз на ТУ"                  int,
                "Из них проведено хозспособом"                     int


            )

AS
$$
# Расчетная сумма финансирования в год ежегодно:
#
year_sum = 347000000  # руб
# Максимальное количество диагностики, проведенной хозспособом:
#
hossposobom = 1000
# 1000 шт (по экспертному мнению)
# Стоимость проведения работ:
#
# Диагностика:
diagn_1 = 36377.01  # ₽
# Паспорт:
passport = 14079.77  # ₽
# ЭПБ:
EPB = 15503.92  # ₽
Target_S = 347000000  # - сумма ассигнований на целевой год. (~347 000 000)
work_P = 36377.01  # - стоимость 1 ТУ (~36000)
work_a_P = 15503.92  # - стоимость оформления документации на 1 ТУ (только оутсорс) ~15000
passport_work_P = 14079.77  # Стоимомсть паспорта (для первичной экспертизы)
primary_Current_N_outsource = 800  # - количество на ПЕРВИЧНУЮ ДИАГНОСТИКУ в ТЕКУЩЕМ ГОДУ
work_VTO_P = 15085.92  # Стоимость 1 ТО/ВТО (~15085.92)
VTO_Current_N = 3000  # - Количество ТО/ВТО в год (потребность)

# Ориентировочное требуемое количество первичных экспертиз:
# 2400
# Распределение по годам (дополнительно к вторичным):
# 2024: 800 шт
# 2025: 800 шт
# 2026: 800 шт

# Стоимость экспертиз:
# Первичная экспертиза: 65 960,70 ₽ (Диагностика + Паспорт + ЭПБ)
# Вторичная экспертиза: 51 880,93 ₽ (Диагностика + ЭПБ)
# Потребность в проведении ТО/ВТО:
#
# Примерно 3000 ТУ в год
# Цена:
TU_price = 15085.92  # ₽

# [p1, p2, p3, p4, p5, p6, p7, p8, startDolg, Target_S, hossposobom]
scenario_2023 = [17.06, 32.79, 24.16, 19.95, 03.0, 00.92, 00.65, 01.48, 112867706.99, 347000000, 1000]
first_real_year = 2024

pervichn = {

    2024: {'kolvo': 800},
    2025: {'kolvo': 800},
    2026: {'kolvo': 800}
}


def raspred_po_procents(p1, p2, p3, p4, p5, p6, p7, p8, history_year, epb_hist):
    p1, p2, p3, p4, p5, p6, p7, p8 = p1 / 100, p2 / 100, p3 / 100, p4 / 100, p5 / 100, p6 / 100, p7 / 100, p8 / 100
    if history_year < first_real_year:
        return epb_hist[history_year]['raspred']
    epb_hist[history_year]['kolvo'] = epb_hist[history_year]['kolvo'] + pervichn.get(history_year, {'kolvo': 0})[
        'kolvo']
    n = epb_hist[history_year]['kolvo']
    ostatok = n
    pps = [p1, p2, p3, p4, p5, p6, p7, p8]
    raspred = [0, 0, 0, 0, 0, 0, 0, 0]
    for i, pp in enumerate(pps):
        pp_n = round(n * pp)
        if ostatok < pp_n:
            raspred[i] = ostatok
            ostatok = 0
        else:
            if i == 7:
                raspred[i] = ostatok
            else:
                raspred[i] = pp_n
                ostatok = ostatok - pp_n

    return raspred


def add_tu_to_years(prodlenia_from_history_year, history_year, epb_hist):
    epb_hist[history_year]['raspred'] = prodlenia_from_history_year
    for i, pp in enumerate(prodlenia_from_history_year):
        target_year = i + 1 + history_year
        if not target_year in epb_hist:
            epb_hist[target_year] = {'raspred': [0, 0, 0, 0, 0, 0, 0, 0], 'kolvo': 0}
        if target_year < first_real_year:
            continue
        epb_hist[target_year]['kolvo'] = epb_hist[target_year]['kolvo'] + pp


def calc_future_prolongs(p1, p2, p3, p4, p5, p6, p7, p8, hossposobom, epb_hist):
    for history_year in range(2017, 2030 + 1):
        if not history_year in epb_hist:
            epb_hist[history_year] = {'raspred': [0, 0, 0, 0, 0, 0, 0, 0], 'kolvo': 0}
        # надо разбить по процентам
        prodlenia_from_history_year = raspred_po_procents(p1, p2, p3, p4, p5, p6, p7, p8, history_year, epb_hist)
        add_tu_to_years(prodlenia_from_history_year, history_year, epb_hist)


def calc_Current_S(vtorich_vsego, vtorich_hoz_sposobom, pervich_N, VTO_N):
    return (vtorich_vsego * (work_a_P + work_P)) - (
            vtorich_hoz_sposobom * work_P) + (
                   pervich_N * (passport_work_P + work_a_P + work_P)) + (
                   VTO_N * work_VTO_P)


def get_srednee_prodlenie(prodlenia: []):
    return round(sum((i + 1) * pp for i, pp in enumerate(prodlenia)) / sum(prodlenia), 2)


def calc_budjets(startDolg, Target_S, hossposobom, epb_hist):
    dolgCurrent = startDolg
    for history_year in range(2017, 2030 + 1):
        if not 'budjet' in epb_hist[history_year]:
            epb_hist[history_year]['budjet'] = {
                'startDolg': 0, 'currentDolg': 0, 'current_S': 0,
                'Средний срок продления': 0,
                'Стоимость проведения Вторичных экспертиз': 0,
                'Стоимость проведения Первичных экспертиз': 0,
                'Стоимость проведения ТО/ВТО': 0,
                'Общая стоимость': 0,
                'Долг на следующий год при текущем финансировании': 0,
                'Проведено вторичных экспертиз': 0,
                'Проведено первичных экспертиз': 0,
                'Всего проведено экспертиз на ТУ': 0,
                'Из них проведено хозспособом': 0
            }
    # в 2023 году долг прописан во входящих
    epb_hist[2023]['budjet']['currentDolg'] = startDolg

    for history_year in range(2017, 2030 + 1):
        data = epb_hist[history_year]
        data['budjet']['Средний срок продления'] = get_srednee_prodlenie(data['raspred'])
        if history_year < first_real_year:
            continue

        pervich_N = pervichn.get(history_year, {'kolvo': 0})['kolvo']
        vtorich_vsego = data['kolvo'] - pervich_N
        if vtorich_vsego > hossposobom:
            vtorich_hoz_sposobom = hossposobom
        else:
            vtorich_hoz_sposobom = vtorich_vsego
        VTO_N = VTO_Current_N

        data['budjet']['startDolg'] = dolgCurrent
        data['budjet']['Стоимость проведения Вторичных экспертиз'] = (vtorich_vsego * (work_a_P + work_P)) - (
                vtorich_hoz_sposobom * work_P);
        data['budjet']['Стоимость проведения Первичных экспертиз'] = pervich_N * (passport_work_P + work_a_P + work_P);
        data['budjet']['Стоимость проведения ТО/ВТО'] = (VTO_N * work_VTO_P);
        data['budjet']['Общая стоимость'] = calc_Current_S(vtorich_vsego, vtorich_hoz_sposobom, pervich_N, VTO_N)
        current_S = calc_Current_S(vtorich_vsego=vtorich_vsego, vtorich_hoz_sposobom=vtorich_hoz_sposobom,
                                   pervich_N=pervich_N, VTO_N=VTO_N)
        dolgCurrent = current_S + dolgCurrent - Target_S
        data['budjet']['current_S'] = current_S
        data['budjet']['Долг на следующий год при текущем финансировании'] = dolgCurrent
        data['budjet']['currentDolg'] = dolgCurrent
        data['budjet']['Проведено вторичных экспертиз'] = vtorich_vsego
        data['budjet']['Проведено первичных экспертиз'] = pervich_N
        data['budjet']['Всего проведено экспертиз на ТУ'] = vtorich_vsego + pervich_N
        data['budjet']['Из них проведено хозспособом'] = vtorich_hoz_sposobom

        columns = ['startDolg', 'currentDolg', 'current_S',
                   'Средний срок продления',
                   'Стоимость проведения Вторичных экспертиз',
                   'Стоимость проведения Первичных экспертиз',
                   'Стоимость проведения ТО/ВТО',
                   'Общая стоимость',
                   'Долг на следующий год при текущем финансировании',
                   'Проведено вторичных экспертиз',
                   'Проведено первичных экспертиз',
                   'Всего проведено экспертиз на ТУ',
                   'Из них проведено хозспособом'
                   ]

    for history_year in range(2017, 2030 + 1):
        epb_hist[history_year]['budjet'] = list([epb_hist[history_year]['budjet'][col] for col in columns])


def main(scenario):
    p1, p2, p3, p4, p5, p6, p7, p8, startDolg, Target_S, hossposobom = scenario
    # год ЭПБ	1	2	3	4	5	6	7	8
    epb_hist = {2017: {'raspred': [450, 463, 624, 760, 150, 0, 0, 0], 'kolvo': None},
                2018: {'raspred': [852, 834, 671, 394, 74, 0, 0, 2750], 'kolvo': None},
                2019: {'raspred': [357, 2997, 2457, 1844, 546, 0, 0, 0], 'kolvo': None},
                2020: {'raspred': [211, 1270, 2815, 1426, 1776, 0, 0, 0], 'kolvo': None},
                2021: {'raspred': [911, 3804, 3290, 669, 429, 0, 0, 0], 'kolvo': None},
                2022: {'raspred': [885, 2821, 2069, 513, 222, 0, 0, 0], 'kolvo': None},
                2023: {'raspred': [1621, 3115, 2295, 1895, 285, 87, 62, 141], 'kolvo': None}}
    calc_future_prolongs(p1, p2, p3, p4, p5, p6, p7, p8, hossposobom=hossposobom, epb_hist=epb_hist)
    calc_budjets(startDolg=startDolg, Target_S=Target_S, hossposobom=hossposobom, epb_hist=epb_hist)
    ret = []
    for history_year in range(2017, 2030 + 1):
        ret.append([])
        ret[-1].extend(
            [history_year] + epb_hist[history_year]['raspred'] + [round(sum([p1, p2, p3, p4, p5, p6, p7, p8]), 2)])
        ret[-1].extend(epb_hist[history_year]['budjet'])
    return ret


# input parameters = [p1, p2, p3, p4, p5, p6, p7, p8] - проценты от 0 -100% +
#    [startDolg, Target_S, hossposobom]

# all_columns_output = ["year", p1, p2, p3, p4, p5, p6, p7, p8, summa_pp,
#  'startDolg', 'currentDolg', 'current_S',
#                    'Средний срок продления',
#                    'Стоимость проведения Вторичных экспертиз',
#                    'Стоимость проведения Первичных экспертиз',
#                    'Стоимость проведения ТО/ВТО',
#                    'Общая стоимость',
#                    'Долг на следующий год при текущем финансировании'
# ]
raspr = main(scenario=[p1, p2, p3, p4, p5, p6, p7, p8, startDolg, Target_S, hossposobom])

return raspr

$$ LANGUAGE plpython3u;

SELECT *,
       replace
           (p3::money::text, '?', 'р')
FROM prodlenie_dash_4.get_table_by_pps_with_budjet(17.06, 32.79, 24.16, 19.95, 03.0, 00.92, 00.65, 01.48, 112867706.99,
                                                   347000000, 1000);
;
SELECT year::text                            as "Год",
       p1                                    as "1",
       p2                                    as "2",
       p3                                    as "3",
       p4                                    as "4",
       p5                                    as "5",
       p6                                    as "6",
       p7                                    as "7",
       p8                                    as "8",
       p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 AS "ВСЕГО"
FROM prodlenie_dash_4.get_table_by_pps_with_budjet;

SELECT *,
       replace
           (p3::money::text, '?', 'р')
FROM prodlenie_dash_4.get_table_by_pps_with_budjet(17.06, 32.79, 24.16, 19.95, 03.0, 00.92, 00.65, 01.48, 112867706.99,
                                                   347000000, 1000);
;
SELECT
    year AS "Год",

 "startDolg"  AS "Долг с прошлого года",
 "Стоимость проведения Вторичных эк"  AS "Стоимость Вторичных экспертиз",
 "Стоимость проведения Первичных эк"  AS "Стоимость Первичных экспертиз",
 "Стоимость проведения ТО/ВТО",
 "Общая стоимость",
 "Долг на следующий год",
 "Проведено вторичных экспертиз",
 "Проведено первичных экспертиз",
 "Всего проведено экспертиз на ТУ",
 "Из них проведено хозспособом",
  "Средний срок продления"
FROM prodlenie_dash_4.get_table_by_pps_with_budjet