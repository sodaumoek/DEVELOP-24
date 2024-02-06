CREATE EXTENSION IF NOT EXISTS plpython3u;



CREATE OR REPLACE FUNCTION prodlenie_dash_4.get_table_by_pps(p1 float, p2 float, p3 float, p4 float, p5 float, p6 float,
                                                             p7 float, p8 float)
    RETURNS TABLE
            (
                year integer,
                p1   integer,
                p2   integer,
                p3   integer,
                p4   integer,
                p5   integer,
                p6   integer,
                p7   integer,
                p8   integer,
                summa_pp float
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

scenario_2023 = [0.1706, 0.3279, 0.2416, 0.1995, 0.03, 0.0092, 0.0065, 0.0148]
first_real_year = 2024



pervichn = {

2024: {'kolvo':800},
2025: {'kolvo':800},
2026: {'kolvo':800}
}

def raspred_po_procents(p1, p2, p3, p4, p5, p6, p7, p8, history_year, epb_hist):
    p1, p2, p3, p4, p5, p6, p7, p8 = p1/100, p2/100, p3/100, p4/100, p5/100, p6/100, p7/100, p8/100
    if history_year < first_real_year:
        return epb_hist[history_year]['raspred']
    epb_hist[history_year]['kolvo'] = epb_hist[history_year]['kolvo'] + pervichn.get(history_year, {'kolvo':0})['kolvo']
    n = epb_hist[history_year]['kolvo']
    ostatok = n
    pps = [p1, p2, p3, p4, p5, p6, p7, p8]
    raspred =[0,0,0,0,0,0,0,0]
    for i, pp in enumerate(pps):
        pp_n = round(n*pp)
        if ostatok<pp_n:
            raspred[i] = ostatok
            ostatok = 0
        else:
            if i == 7:
                raspred[i] = ostatok
            else:
                raspred[i] = pp_n
                ostatok = ostatok-pp_n

    return raspred


def add_tu_to_years(prodlenia_from_history_year, history_year, epb_hist):
    epb_hist[history_year]['raspred'] = prodlenia_from_history_year
    for i, pp in enumerate (prodlenia_from_history_year):
        target_year = i + 1 + history_year
        if not target_year in epb_hist:
            epb_hist[target_year] = {'raspred':[0, 0, 0, 0, 0, 0, 0, 0], 'kolvo':0}
        if target_year < first_real_year:
            continue
        epb_hist [target_year]['kolvo'] = epb_hist[target_year]['kolvo'] + pp




def calc_future_prolongs(p1, p2, p3, p4, p5, p6, p7, p8, hossposobom, epb_hist):
    for history_year in range(2017, 2030 + 1):
        if not history_year in epb_hist:
            epb_hist[history_year] = {'raspred':[0, 0, 0, 0, 0, 0, 0, 0], 'kolvo':0}
        # надо разбить по процентам
        prodlenia_from_history_year = raspred_po_procents(p1, p2, p3, p4, p5, p6, p7, p8, history_year,epb_hist)
        add_tu_to_years(prodlenia_from_history_year, history_year, epb_hist)


def main(scenario):
    # год ЭПБ	1	2	3	4	5	6	7	8
    epb_hist = {2017: {'raspred':[450, 463, 624, 760, 150, 0, 0, 0], 'kolvo':None},
                2018: {'raspred':[852, 834, 671, 394, 74, 0, 0, 2750], 'kolvo':None},
                2019: {'raspred':[357, 2997, 2457, 1844, 546, 0, 0, 0], 'kolvo':None},
                2020: {'raspred':[211, 1270, 2815, 1426, 1776, 0, 0, 0], 'kolvo':None},
                2021: {'raspred':[911, 3804, 3290, 669, 429, 0, 0, 0], 'kolvo':None},
                2022: {'raspred':[885, 2821, 2069, 513, 222, 0, 0, 0], 'kolvo':None},
                2023: {'raspred':[1621, 3115, 2295, 1895, 285, 87, 62, 141], 'kolvo':None}}
    calc_future_prolongs(*scenario, hossposobom=hossposobom, epb_hist=epb_hist)
    ret = []
    for history_year in range(2017, 2030 + 1):
        ret.append([])
        ret[-1].extend([history_year] + epb_hist[history_year]['raspred'] + [round(sum([p1, p2, p3, p4, p5, p6, p7, p8]), 2)] )
    return ret

#if sum([p1, p2, p3, p4, p5, p6, p7, p8]) != 1:
#    return [[0,0,0,0,0,0,0,0,0]]
raspr = main(scenario = [p1, p2, p3, p4, p5, p6, p7, p8])
return raspr

$$ LANGUAGE plpython3u;

SELECT * FROM prodlenie_dash_4.get_table_by_pps(17.06, 32.79, 24.16, 19.95, 03.0, 00.92, 00.65, 01.48);
