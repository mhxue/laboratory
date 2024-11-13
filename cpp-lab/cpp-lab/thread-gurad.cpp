//
//  thread-gurad.cpp
//  cpp-lab
//
//  Created by minghao xue on 2024/11/13.
//

#include "thread-gurad.hpp"
#include <iostream>
#include <thread>
#include <stack>
#include <mutex>

using namespace std;

class thread_safe_stack {
private:
    stack<int> st;
    mutex m;
public:
    void push(int value) {
        lock_guard<mutex> lock(m);
        st.push(value);
    }
    
    shared_ptr<int> pop() {
        lock_guard<mutex> lock(m);
        
        if (st.empty()) {
            throw "stack is empty";
        }
        
        shared_ptr<int> res = make_shared<int>(st.top());
        st.pop();
        return res;
    }
    
    bool empty() {
        lock_guard<mutex> lock(m);
        return st.empty();
    }
};

void run_thread_guard() {
    thread_safe_stack ss;
    ss.push(1);
    thread t([&ss] {
        ss.push(4);
    });
    ss.push(2);
    thread t1([&ss] {
        ss.push(3);
    });
    t.join();
    t1.join();
    
    while (!ss.empty()) {
        cout << *ss.pop().get() << " ";
    }
    cout << endl;
    cout << "End run of run thread guard" << endl;
}
