#!/usr/bin/python3

from plotter import Plotter


def main():
        p = Plotter()
        p.init()
        p.plot_throughput()
        p.plot_bars(packet_size=65536)
        p.plot_bars(packet_size=32768)
        p.plot_bars(packet_size=16384)
        p.plot_bars(packet_size=1)


if __name__ == '__main__':
        main()
