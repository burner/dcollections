/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how lists can be used.
 */
import dcollections.ArrayList;
import dcollections.LinkList;
import dcollections.Deque;
import std.stdio;

void print(Iterator!(int) s, string message)
{
    write(message ~ " [");
    foreach(i; s)
        write(" ", i);
    writeln(" ]");
}


void main()
{
    auto arrayList = new ArrayList!(int);
    auto linkList = new LinkList!(int);
    auto deque = new Deque!(int);

    for(int i = 0; i < 10; i++)
        arrayList.add(i*5);
    print(arrayList, "filled in arraylist");


    //
    // add all the elements from arraylist to linklist
    //
    linkList.add(arrayList);
    print(linkList, "filled in linkList");
    deque.add(linkList);
    print(deque, "filled in deque");

    //
    // you can compare lists
    //
    if(arrayList == linkList)
        writeln("equal!");
    else
        writeln("not equal!");

    //
    // you can concatenate lists together
    //
    arrayList ~= linkList;
    print(arrayList, "appended linkList to arrayList");
    linkList = linkList ~ arrayList;
    print(linkList, "concatenated linkList and arrayList");

    //
    // you can purge elements from a list
    //
    // removes all odd elements in the list.
    foreach(ref doPurge, i; &linkList.purge)
        doPurge = (i % 2 == 1);
    print(linkList, "removed all odds from linkList");

    //
    // you can slice ArrayLists
    //
    auto slice = arrayList[5..10];
    writefln("slice of arrayList: [%s]", slice);

    //
    // pushing to a deque front is as efficient as pushing to the back  It also
    // does not invalidate any ranges.
    //
    deque.prepend(1).prepend(2).prepend(3);
    print(deque, "pushed 1 2 3 to front");

    //
    // and slices seamlessly can get data from both front and back
    //
    writefln("slice of deque[0..2]: %s, [0..5]: %s, [1..5]: %s, [4..8]: %s", deque[0..2], deque[0..5], deque[1..5], deque[4..8]);
}
