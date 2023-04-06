#!/usr/bin/python3

import json
from typing import List, Dict, Any
from pathlib import Path
from logging import Logger

import matplotlib.pyplot as plt
import matplotlib.colors as mcolors


logger = Logger(__name__)


class PlotterException(Exception):
        pass


class MissingSamples(PlotterException):
        pass


class TooManySamples(PlotterException):
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


        def _read_samples(self) -> List[Dict]:
                json_data = list()

                for path in self._samples_dir.iterdir():
                        with path.open() as fp:
                                data = json.load(fp)
                                json_data.append(data)

                return json_data
        

        @staticmethod
        def get_cmap(n, name='hsv'):
                '''
                Returns a function that maps each index in 0, 1, ..., n-1 to a distinct RGB color; 
                the keyword argument name must be a standard mpl colormap name.
                '''
                return plt.cm.get_cmap(name, n)


        @staticmethod
        def _plot_single_sample(sample: Dict[str, Any], color: str) -> None:
                sample_title = sample['title']
                plt.plot(
                        sample['x_values'], 
                        sample['y_values'], 
                        label=sample_title, 
                        color=color,
                        linestyle="--",
                        markersize=12
                )


        @classmethod
        def _save_to_file(cls, filename: str) -> None:
                pdf_path = cls.DEFAULT_OUTPUT_PLOTS_DIR / (filename + '.pdf')
                png_path = cls.DEFAULT_OUTPUT_PLOTS_DIR / (filename + '.png')

                plt.savefig(pdf_path, format='pdf')
                plt.savefig(png_path, format='png')



        def plot_throughput(self) -> None:
                samples = self._read_samples()

                for i, sample in enumerate(samples):
                        if sample['valid'] != 'true' or sample['type'] != 'regular':
                                continue
                        max_colors = len(mcolors.BASE_COLORS)
                        if i >= max_colors:
                                logger.warning(f'This script only supports up to {max_colors} samples on the same graph')
                                raise TooManySamples()

                        self._plot_single_sample(sample, color=list(mcolors.BASE_COLORS.keys())[i])
                        

                plt.xlabel('Packet Size [Bytes]')
                plt.ylabel('Throughput [Mbps]')
                plt.legend()
                plt.title('Throughput - Packet Size')

                self._save_to_file(filename='throughput') 

def main():
        p = Plotter()
        p.init()
        p.plot_throughput()
#        p.plot_bars()
 
def generate_plots():
        # io uring - multicore (8 cores) - batch=1
        # throughput6 = [172, 1905, 7215, 28223, 28291, 27866, 28105][:len(size)]
        # io uring - multicore (8 cores) - batch=64
        # throughput8 = [197, 2471, 8903, 28044, 28396, 28191, 27620][:len(size)]
        # io uring - multicore (8 cores) - zero copy - batch=64
        # throughput7 = [216, 282, 483, 2513, 7378, 25839, 27703][:len(size)]

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


if __name__ == '__main__':
        main()
