//
//  main.cpp
//  cpp-lab
//
//  Created by minghao xue on 2024/11/12.
//

#include <iostream>
#include <thread>

#include "thread-basic.hpp"
#include "thread-safe-join.hpp"
#include "thread-background.hpp"
#include "thread-with-arguments.hpp"
#include "thread-gurad.hpp"

using namespace std;

int main(int argc, const char * argv[]) {
    
//    cout << thread::hardware_concurrency() << endl;
//    
//    cout << this_thread::get_id() << endl;
    
//    run_basic_usage();
//    run_thread_safe_join();
//    run_detached_background_thread();
//    run_thread_with_arguments();
    run_thread_guard();
    return 0;
}
