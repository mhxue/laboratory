//
//  thread-with-arguments.cpp
//  cpp-lab
//
//  Created by minghao xue on 2024/11/13.
//

#include "thread-with-arguments.hpp"
#include <iostream>
#include <thread>

using namespace std;

void do_some_work(int count, string const& message) {
    for (int i = 0; i < count; i++) {
        cout << "Doing work: " << i;
        if (i < message.size()) {
            cout << " " << message[i];
        }
        cout << endl;
    }
}

void run_thread_with_arguments() {
    thread t(do_some_work, 5, "Hello World!");
    t.join();
}
