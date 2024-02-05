import decimal
step = 2.5
selectors_n = 8
def drange(x, y, jump):
  while x < y:
    yield float(x)
    x += decimal.Decimal(jump)

combs_number = 0
combs = []
def get_combs_rec(summa, selector):
    global combs_number
    if selector == 8 or summa == 0:
        if summa < 0:
            return
        combs_number = combs_number + 1
        return
    for v in drange(0, summa+1, step):
        get_combs_rec(summa-v, selector+1)

get_combs_rec(100, 1)
print(combs_number)


