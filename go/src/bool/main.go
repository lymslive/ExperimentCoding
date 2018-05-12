package main

import "fmt"

func main() {
	var str string
	var i int

	str = "xx"
	if str == "" {
		fmt.Println("empty string")
	} else {
		fmt.Println("non empty string: ", str)
	}

	i = 4
	if i != 0 {
		fmt.Println("non zoro int: ", i)
	} else {
		fmt.Println("zoro int: ", i)
	}
}

/*
不能直接用 if !str 或 if !i
*/
