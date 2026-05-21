#include <iostream>
#include <cstdlib>
#include <ctime>
#include<string>
#include<vector>
using namespace std;


int ReadNumber(string message) {

	int num = 0;

	while (num <= 0) {

		cout << message << endl;

		cin >> num;


	}
	return num;


}

int RandomNumber(int From, int To)
{

	int randNum = rand() % (To - From + 1) + From;

	return randNum;
}





int main()
{
	srand((unsigned)time(NULL));

	int num = ReadNumber("Enter a positive number : \n");
	vector<int> numbers(num);
	for (int i = 0;i < num;i++) {

		int x = RandomNumber(0, 9);
		
		cout << "Elements [" << i + 1 << "] : " << x ;
		
		cout << endl;

		numbers[i] = x;
	}
	int check_number = 0;
	cout << "Which number you need to check : \n";
	cin >> check_number;

	int counter = 0;
	cout << "Original array : ";
	for (int y = 0;y < num;y++) {

		if (check_number == numbers[y]) {

			counter++;
		}


		cout  << numbers[y]<<" ";
	}
	cout << endl;
	if (counter != 0) {

		cout << "Number: " << check_number << " was repeated: " << counter << " Time(s)";
	}
	else {

		cout << "we could not find your number;";
	}

/*Here we are going to check how many times the number the user enters is reperated in the program */
}
