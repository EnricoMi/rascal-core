module lang::rascalcore::compile::Examples::Tst2

data Aap(int aap=4) = aap();

value main(){
    b=aap(noot=7);
    node c = b;
    return c.noot;
}      

//data B = and(B l, B r) | or(B l, B r)  | t() | f();
  
//B build(B(B,B) cons, B l, B r) = cons(l, r);

//data B  = b(int n);
//
//int f(int n) = n;
//
//B g(int a, B(int) fun) = fun(a); 
//     
//value main() = g(3, b);
          
//value main() = build(and, t(), f());
       
//value main () = and(t(), f());

//value hello() {
//  return build(and, t(), f());
//}
//
//data F = f() | g();
//
//int func(f()) = 1;
//int func(g()) = 2;
//
//int apply(int (F) theFun, F theArg) = theFun(theArg);
//
//int main() = apply(func, f());
  
//test bool tstLast(list[&T] L) = (isEmpty(L) || eq(last(L),elementAt(L,-1)));

//test bool tstUnzip2(list[tuple[&A, &B]] L) = unzip(L) == <[a | <a,b> <- L], [b | <a,b> <- L]>;

//import util::Math;
//value main() =  toReal(3) == 3.;

 
//value main() { lrel[int,int] L = []; return unzip(L);}
// 
//import List; 
//import Type;
//   
// test bool dtstIntersection(list[int] lst) {
//             
//    if([*int l1,*int l2] := lst) {
//        lhs1 = l1 & l2;
//     }
//    return true;
//}


 //test bool tstIntercalate(str sep, list[value] L) = 
 //      "abc" == (isEmpty(L) ? ""
 //                           : "<L[0]><for(int i <- [1..size(L)]){><sep><L[i]><}>");