#!/usr/bin/python3

from plotter import Plotter


def main():
        p = Plotter()
        p.init()
        p.plot_throughput()
        p.plot_bars()


if __name__ == '__main__':
        main()
