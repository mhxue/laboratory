//
//  thread-safe-join.cpp
//  cpp-lab
//
//  Created by minghao xue on 2024/11/13.
//

#include "thread-safe-join.hpp"
#include <iostream>
#include <thread>

using namespace std;

class ThreadSafeJoin {
private:
    thread &_t;
public:
    ThreadSafeJoin(thread &t): _t(t) {};
    ThreadSafeJoin(ThreadSafeJoin const&) = delete;
    ThreadSafeJoin& operator=(ThreadSafeJoin const&) = delete;
    ~ThreadSafeJoin() {
        if (_t.joinable()) {
            _t.join();
            cout << "Joined thread at the descruction method of threadsafejoin" << endl;
        }
    }
};

class ThreadSafeJoinV2 {
private:
    thread _t;
public:
    ThreadSafeJoinV2(thread t): _t(std::move(t)) {
        if (!_t.joinable()) {
            throw std::logic_error("No thread");
        }
    };
    
    ~ThreadSafeJoinV2() {
        _t.join();
    }
    
    ThreadSafeJoinV2(ThreadSafeJoinV2 const &) = delete;
    ThreadSafeJoinV2& operator=(ThreadSafeJoinV2 const &) = delete;
};

void run_with_exception() {
    try {
        thread t([] {
            cout << "Hello from thread safe join thread" << endl;
        });
        ThreadSafeJoin tsj(t);
        ThreadSafeJoinV2 tsjv2(thread([] {
            cout << "Hello from thread safe join thread v2" << endl;
        }));
//        throw 1; // Even there is an exception here, the thread will be joined correctly
//        t.join();
        cout << "End of thread safe join run" << endl;
    } catch(int error_code) {
        
    }
}

void run_thread_safe_join() {
    run_with_exception();
}
