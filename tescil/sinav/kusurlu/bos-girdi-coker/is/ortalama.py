import sys
sayilar = [float(x) for x in sys.argv[1:]]
o = sum(sayilar) / len(sayilar)
print(int(o) if o == int(o) else o)
