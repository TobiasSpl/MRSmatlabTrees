# -*- coding: utf-8 -*-
"""
Created on Mon Jan 15 13:12:20 2024

@author: Splith.T
"""

import multiprocessing
from time import sleep

def init(queue):
    global idx
    idx = queue.get()

def f(x):
    global idx
    process = multiprocessing.current_process()
    sleep(1)
    return (idx, process.pid, x * x)

if __name__ == '__main__':
    ids = [0, 1, 2, 3]
    manager = multiprocessing.Manager()
    idQueue = manager.Queue()
    
    for i in ids:
        idQueue.put(i)
    
    p = multiprocessing.Pool(8, init, (idQueue,))
    print(p.map(f, range(8)))