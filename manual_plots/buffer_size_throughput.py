#!/usr/bin/python3


import matplotlib.pyplot as plt
 
 
size = [32, 128, 1024, 4096, 16384, 32768]

throughput1 = [387, 1328 , 6671, 14121, 19284, 19597]
throughput2 = [463, 1622, 8816, 17137, 22307, 21290]
throughput3 = [305, 1115, 6449, 14949, 20958, 20013] 
throughput4 = [305, 1120, 6683, 15470, 21100, 19875]
# Without COOP_TASKRUN, this is same as netperf!



plt.scatter(
        size, 
        throughput1, 
        label="netperf", 
        color="green",
        marker="+",
        s=30 
        )


plt.scatter(
        size, 
        throughput2, 
        label="uring batch=64 (optimal)", 
        color="red",
        marker="*",
        s=30 
        )

plt.scatter(
        size, 
        throughput3, 
        label="uring batch=1 (COOP_TASKRUN enabled)", 
        color="blue",
        marker="D",
        s=30 
        )

plt.scatter(
        size, 
        throughput4, 
        label="uring batch=1 (COOP_TASKRUN disabled)", 
        color="black",
        marker="^",
        s=30 
        )

#figure.text(0.5, 0.04, 'Buffer Size [#Bytes]', ha='center')
#figure.text(0.04, 0.5,'throughput [Gbps]', va='center', rotation='vertical')
plt.xlabel('Buffer Size [#Bytes]')
plt.ylabel('Throughput [Gbps]')

plt.legend()

plt.title('Throughput (Buffer Size)')

plt.savefig('buffer_size_throughput.pdf', format='pdf')

