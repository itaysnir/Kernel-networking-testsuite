#!/usr/bin/python3


import matplotlib.pyplot as plt
 
 
batch = [1, 8, 16, 32, 64, 96, 128]

throughput1_n = [19572, 19572, 19572, 19572, 19572, 19572, 19572]
throughput1 = [20596, 20893, 21256, 21722, 22776, 22216, 21151]
throughput2_n = [6447, 6447, 6447, 6447, 6447, 6447, 6447]
throughput2 = [6375, 8219, 8663, 8717, 8780, 8681, 8642]
throughput3_n = [42, 42, 42, 42, 42, 42, 42]
throughput3 = [42, 43, 44, 45, 47, 46, 45]

'''
figure, axis = plt.subplots(3, 1, sharex=True)
axis[0].scatter(
        batch, 
        throughput1, 
        label="Chunk Size = 16KB", 
        color="green",
        marker="+",
        s=30 
        )
axis[0].set_title("16KB")


axis[1].scatter(
        batch, 
        throughput2, 
        label="Chunk Size = 64B", 
        color="red",
        marker="*",
        s=30 
        )
axis[1].set_title("64B")


axis[2].scatter(
        batch, 
        throughput3, 
        label="Chunk Size = 1B", 
        color="blue",
        marker="D",
        s=30 
        )
axis[2].set_title("1B")


#plt.xlabel('batch[#submit-requests]')
#plt.ylabel('throughput[Gbps]')

figure.text(0.5, 0.04, 'Batch [#submit-requests]', ha='center')
figure.text(0.04, 0.5,'Throughput [Gbps]', va='center', rotation='vertical')

plt.suptitle('IO Uring - TCP TX - Throughput (Batch)')
'''


plt.scatter(
        batch,
        throughput1_n,
        label="netperf 16KB",
        color="orange",
        marker="+",
        s=30
        )

plt.scatter(
        batch,
        throughput1,
        label="uring 16KB",
        color="green",
        marker="+",
        s=30
        )

plt.scatter(
        batch,
        throughput2_n,
        label="netperf1KB",
        color="purple",
        marker="+",
        s=30
        )

plt.scatter(
        batch,
        throughput2,
        label="uring 1KB",
        color="red",
        marker="+",
        s=30
        )

plt.scatter(
        batch,
        throughput3_n,
        label="netperf 1B",
        color="black",
        marker="+",
        s=30
        )

plt.scatter(
        batch,
        throughput3,
        label="uring 1B",
        color="blue",
        marker="+",
        s=30
        )

plt.xlabel('Batch [#submit-requests]')
plt.ylabel('Throughput [Gbps]')

plt.legend(prop={'size': 6})

plt.title('Throughput (batch)')


plt.savefig('io_uring_tcp_tx_batch.pdf', format='pdf')
plt.savefig('io_uring_tcp_tx_batch.png', format='png')
