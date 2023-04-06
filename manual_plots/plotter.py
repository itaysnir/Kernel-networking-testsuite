#!/usr/bin/python3

import json
from typing import List
from pathlib import Path
from logging import Logger

import matplotlib.pyplot as plt


logger = Logger(__name__)


class PlotterException(Exception):
        pass


class MissingSamples(PlotterException):
        pass


class Plotter:
        DEFAULT_SAMPLES_DIR = Path('samples')
        DEFAULT_OUTPUT_PLOTS_DIR = Path('plots')

        def __init__(self, samples_dir: Path = DEFAULT_SAMPLES_DIR) -> None:
                self._samples_dir: Path = samples_dir
                

        def init(self) -> None:
                if not self._samples_dir.exists():
                        logger.warning(f'Samples dir: directory {self._samples_dir} is missing')
                        raise MissingSamples()

                self.DEFAULT_OUTPUT_PLOTS_DIR.mkdir(exist_ok=True)


        def _read_samples(self) -> List[]:
                json_data = list()

                for sample in self._samples_dir.iterdir():
                        with sample.open() as fp:
                                json_data.append(json.load(fp))


        def plot(self) -> None:
                samples = self._read_samples()


def main():
        p = Plotter()
        p.init()
        p.plot()
 
def generate_plots():
 
        size = [1, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536]

        large_index = 6
        start_index = 0
        end_index = len(size)

        size = size[start_index:end_index]

        # netperf 
        throughput1 = [42, 190, 357, 684, 1328, 2293, 4135, 6671, 10048, 14121, 17726, 19821, 20225, 20047][start_index:end_index]

        # io uring - send - batch=64
        throughput2 = [46, 235, 463, 859, 1622, 2960, 5376, 8816, 13884, 17137, 22456, 23058, 22341, 22148][start_index:end_index]


        # io uring - regular - batch=1
        throughput3 = [42, 154, 287, 543, 1115, 1985, 3593, 6449, 10241, 14949, 20473, 20958, 20990, 21339][start_index:end_index]


        # io uring - zero copy - batch=64
        throughput5 = [184, 218, 249, 319, 445, 726, 1170, 2138, 3828, 7095, 13988, 20510, 27578, 27521][start_index:end_index]


        # io uring - multicore (8 cores) - batch=1
        # throughput6 = [172, 1905, 7215, 28223, 28291, 27866, 28105][:len(size)]


        # io uring - multicore (8 cores) - batch=64
        # throughput8 = [197, 2471, 8903, 28044, 28396, 28191, 27620][:len(size)]


        # io uring - multicore (8 cores) - zero copy - batch=64
        # throughput7 = [216, 282, 483, 2513, 7378, 25839, 27703][:len(size)]



        plt.plot(
                size, 
                throughput1, 
                label="netperf", 
                color="green",
                linestyle="--",
                marker="+",
                markersize=12
        )


        plt.plot(
                size, 
                throughput2, 
                label="uring batch=64 (optimal)", 
                color="red",
                linestyle="--",
                marker="+",
                markersize=12 
        )

        plt.plot(
                size, 
                throughput3, 
                label="uring batch=1", 
                color="yellow",
                linestyle="--",
                marker="+",
                markersize=12 
        )

        plt.plot(
                size,
                throughput5,
                label="uring zerocopy batch=64",
                color="blue",
                linestyle="--",
                marker="+",
                markersize=12
        )

        '''
        plt.scatter(
        size, 
        throughput6, 
        label="uring multicore=8 batch=1", 
        color="yellow",
        marker="+",
        s=30 
        )

        plt.scatter(
        size, 
        throughput8, 
        label="uring multicore=8 batch=64", 
        color="blue",
        marker="+",
        s=30 
        )

        plt.scatter(
        size, 
        throughput7, 
        label="uring zerocopy multicore=8 batch=64", 
        color="purple",
        marker="+",
        s=30 
        )
        '''

        #plt.xscale('log')

        plt.xlabel('Buffer Size [#Bytes]')
        plt.ylabel('Throughput [Mbps]')

        plt.legend()

        plt.title('Buffer Size - Throughput')

        plt.savefig('buffer_size_throughput.pdf', format='pdf')
        plt.savefig('buffer_size_throughput.png', format='png')


if __name__ == '__main__':
        main()
