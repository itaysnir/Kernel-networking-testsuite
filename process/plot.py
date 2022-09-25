#!/usr/bin/python3
##!/usr/local/bin/python3
import numpy as np
import matplotlib.pyplot as pl
from matplotlib.backends.backend_pdf import PdfPages
import pandas as pd
import argparse

parser = argparse.ArgumentParser(description='Generic plotter from 2 csvs')
#parser.add_argument('integers', metavar='N', type=int, nargs='+', help='an integer for the accumulator')
parser.add_argument('exp', metavar='Experiment', help='name of experiment')
parser.add_argument('-v', '--display', action='store_true', help='Display the graph')
args = parser.parse_args()

exp = pd.read_csv(args.exp + '.csv', index_col=0, sep=',');

#config spaces betwwen plots
pl.subplots_adjust(wspace=0.2, left=0.07, right=0.95, bottom=0.2)
pl.suptitle(args.exp.replace("_"," "));

pl.bar(exp.index, exp['bandwidth']);
pl.xticks(exp.index, exp.setup, rotation=-45)

#def subplot(field, Text, divisor = 1):
##working on plot 1
#pl.plot(exp_l.index, exp_l[field]/divisor, linestyle='--', marker='*', label='Local', linewidth=2, color='g')
#pl.plot(exp_r.index, exp_r[field]/divisor, marker='x', label='Remote',color='y')
#pl.legend()
##xtics n lables
#pl.xticks(exp_l.index, exp_l.msg_size, rotation=-45)
#pl.title(Text);
#pl.grid(axis='y')
#
#list_l = exp_l[field].tolist()
#list_r = exp_r[field].tolist()
#lables = []
#
#for i in range(len(exp_l.index)):
#	if  (list_r[i] > 0):
#		lables.append("%.2f" % (list_l[i]/list_r[i]))
#	else:
#		lables.append("nan")
#
#for i in range(len(exp_l.index)):
#    pl.text(x = i+1 , y = list_l[i]/divisor * 1.03 , s = lables[i] , size = 10, color='r')
#
#pl.ylim(bottom=0, top=1.1 * max(max(list_l), max(list_r))/divisor)


#pl.subplot(133)
#subplot('cpu_total', "CPU util [cores]", 100/28)

pl.savefig(args.exp + '.pdf', format='pdf');
if args.display:
	pl.show()
