//
//  thread-background.cpp
//  cpp-lab
//
//  Created by minghao xue on 2024/11/13.
//

#include "thread-background.hpp"
#include <iostream>
#include <thread>

using namespace std;

void run_detached_background_thread() {
    thread t([] {
        for (int i = 0; i < 100; i++) {
            this_thread::sleep_for(chrono::seconds(1));
            cout << "Hello from background thread: " << i << endl;
        }
    });
    t.detach();
    this_thread::sleep_for(chrono::seconds(10));
    cout << "End of run background thread" << endl;
}
