//
//  thread-basic.cpp
//  cpp-lab
//
//  Created by minghao xue on 2024/11/13.
//

#include "thread-basic.hpp"
#include <iostream>
#include <thread>

using namespace std;

class ThreadEntry {
public:
    void operator()() const {
        cout << "Hello from callable thread" << endl;
    }
};

void run_callable_test() {
    thread t{ThreadEntry()};
    t.join(); // A thread must be joined or detached, or an exception will be raised once the new created thread got de-constructed. see: https://gcc.gnu.org/onlinedocs/libstdc++/libstdc++-api-4.5/a01060_source.html#:~:text=__args...)))%3B%20%7D%0A00142%20%0A00143%20%20%20%20%20~-,thread,-()%0A00144%20%20%20%20%20%7B
    // Also see: https://en.cppreference.com/w/cpp/error/terminate
    cout << "End of callable run" << endl;
}

void say_greetings() {
    cout << "Hello from simple thread" << endl;
}

void run_simple_thread() {
    thread t(say_greetings);
    t.join();
    cout << "End of simple thread run" << endl;
}

void run_basic_usage() {
    run_simple_thread();
    run_callable_test();
}
