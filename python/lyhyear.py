money = 10000
white = money * 100
rate = 5
white_unit = white / 10000

red_sum = 0
day = 0
day_red = 0
while white_unit > 1:
    day = day + 1
    day_red = white_unit * rate
    red_sum = red_sum + day_red
    white = white - day_red
    white_unit = white / 10000
    if day > 365:
        break

print(red_sum/100)
