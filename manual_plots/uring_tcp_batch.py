#!/usr/bin/python3


import matplotlib.pyplot as plt
 
 
batch = [1, 8, 16, 32, 64, 96, 128]

throughput1 = [20596, 20893, 21256, 21722, 22776, 22216, 21151]
throughput2 = [560, 807, 831, 853, 868, 860, 851]
throughput3 = [24, 27, 28, 28, 29, 30, 30]


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

plt.savefig('io_uring_tcp_tx_batch.pdf', format='pdf')
plt.savefig('io_uring_tcp_tx_batch.png', format='png')
