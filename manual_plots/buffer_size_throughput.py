#!/usr/bin/python3


import matplotlib.pyplot as plt
 
 
#size = [1, 32, 128, 1024, 4096, 16384, 32768]
size = [1, 32, 128]

# netperf 
throughput1 = [42, 357, 1328 , 6671, 14121, 19284, 19597][:len(size)]

# io uring - regular - batch=64
throughput2 = [46, 463, 1622, 8816, 17137, 22307, 21290][:len(size)]


# io uring - regular - batch=1
#throughput3 = [42, 287, 1115, 6449, 14949, 20958, 20013] [:len(size)]

# io uring - COOP_TASKRUN disabled - batch=1
#throughput4 = [290, 1120, 6683, 15470, 21100, 19875]  [:len(size)]


# io uring - zero copy - batch=64
throughput5 = [184, 249, 445, 2138, 7095, 20510, 27578][:len(size)]


# io uring - multicore (8 cores) - batch=1
throughput6 = [172, 1905, 7215, 28223, 28291, 27866, 28105][:len(size)]


# io uring - multicore (8 cores) - batch=64
throughput8 = [197, 2471, 8903, 28044, 28396, 28191, 27620][:len(size)]


# io uring - multicore (8 cores) - zero copy - batch=64
throughput7 = [216, 282, 483, 2513, 7378, 25839, 27703][:len(size)]



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
        marker="+",
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
        color="black",
        marker="+",
        s=30 
        )

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



plt.xlabel('Buffer Size [#Bytes]')
plt.ylabel('Throughput [Gbps]')

plt.legend()

plt.title('Throughput (Buffer Size)')

plt.savefig('buffer_size_throughput.pdf', format='pdf')
plt.savefig('buffer_size_throughput.png', format='png')
