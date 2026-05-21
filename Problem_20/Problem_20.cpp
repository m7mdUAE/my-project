#include <iostream>
#include <cstdlib>
#include <ctime>
using namespace std;

int main()
{
    srand(time(0));

    char a = rand() % 26 + 97;
	char b = rand() % 26 + 65;
    char c = rand() % 13 + 33;
    char d = rand() % 10 + 48;



    cout << a << endl;
    cout << b << endl;
    cout << c << endl;
    cout << d << endl;

    return 0;
}