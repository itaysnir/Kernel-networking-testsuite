#!/usr/bin/python3


import matplotlib.pyplot as plt
 
 
size = [32, 128, 1024, 4096, 16384, 32768]

# netperf 
throughput1 = [387, 1328 , 6671, 14121, 19284, 19597]

# io uring - regular - batch=64
throughput2 = [463, 1622, 8816, 17137, 22307, 21290]

# io uring - regular - batch=1
#throughput3 = [305, 1115, 6449, 14949, 20958, 20013] 

# io uring - COOP_TASKRUN disabled - batch=1
#throughput4 = [305, 1120, 6683, 15470, 21100, 19875]  

# io uring - zero copy - batch=64
throughput5 = [249, 445, 2138, 7095, 20510, 27578]

# io uring - multicore (8 cores) - batch=64
throughput6 = [27006]

# io uring - multicore (8 cores) - zero copy - batch=64
throughput7 = [27703]


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

# plt.scatter(
#         size, 
#         throughput3, 
#         label="uring batch=1 (COOP_TASKRUN enabled)", 
#         color="blue",
#         marker="D",
#         s=30 
#         )
# 
# plt.scatter(
#         size, 
#         throughput4, 
#         label="uring batch=1 (COOP_TASKRUN disabled)", 
#         color="black",
#         marker="^",
#         s=30 
#         )

plt.scatter(
        size, 
        throughput5, 
        label="uring zerocopy batch=64", 
        color="gold",
        marker="o",
        s=30 
        )

plt.xlabel('Buffer Size [#Bytes]')
plt.ylabel('Throughput [Gbps]')

plt.legend()

plt.title('Throughput (Buffer Size)')

plt.savefig('buffer_size_throughput.pdf', format='pdf')
plt.savefig('buffer_size_throughput.png', format='png')
