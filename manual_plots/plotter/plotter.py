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
        DEFAULT_OUTPUT_PLOTS_DIR = Path('result_plots')

        def __init__(self, samples_dir: Path = DEFAULT_SAMPLES_DIR) -> None:
                self._samples_dir: Path = samples_dir
                self._samples: List[Dict[str, Any]] = None
                

        def init(self) -> None:
                if not self._samples_dir.exists():
                        logger.warning(f'Samples dir: directory {self._samples_dir} is missing')
                        raise MissingSamples()

                self.DEFAULT_OUTPUT_PLOTS_DIR.mkdir(exist_ok=True)

                self._samples = self._read_samples()


        def _read_samples(self) -> List[Dict[str, Any]]:
                json_data = list()

                for path in self._samples_dir.iterdir():
                        with path.open() as fp:
                                data = json.load(fp)
                                json_data.append(data)

                return json_data
        

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
                for i, sample in enumerate(self._samples):
                        if sample['valid'] != 'true':
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

                self._save_to_file(filename='throughput-all') 


        def plot_bars(self) -> None:
                fig = plt.figure()
                ax = fig.add_axes([0.15,0.15,0.7,0.7])
                plt.xticks(rotation=20)

                networking_type = list()
                throughput_64k = list()

                for sample in self._samples:
                        if sample['valid'] != 'true':
                                continue
                        networking_type.append(sample['title'])
                        throughput_64k.append(sample['y_values'][-1])
                
                ax.bar(networking_type, throughput_64k)

                plt.ylabel('Throughput [Mbps]')
                plt.title('Throughput - 64K Packets')

                self._save_to_file(filename='throughput-64k')
