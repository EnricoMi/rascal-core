module lang::rascalcore::compile::muRascal2Java::Conversions

import Node;
import String;
import Map;
import Set;
import ParseTree;

extend lang::rascalcore::check::CheckerCommon;

import lang::rascal::\syntax::Rascal;
import lang::rascalcore::compile::util::Names;
import lang::rascalcore::compile::muRascal2Java::JGenie;

data JGenie; // hack to break cycle?

/*****************************************************************************/
/*  Convert AType to a Java type                                             */
/*****************************************************************************/

str atype2javatype(abool())                 = "IBool";
str atype2javatype(aint())                  = "IInteger";
str atype2javatype(areal())                 = "IReal";
str atype2javatype(arat())                  = "IRational";
str atype2javatype(anum())                  = "INumber";
str atype2javatype(astr())                  = "IString";
str atype2javatype(aloc())                  = "ISourceLocation";
str atype2javatype(adatetime())             = "IDateTime";
str atype2javatype(alist(AType t))          = "IList";
str atype2javatype(aset(AType t))           = "ISet";
str atype2javatype(arel(AType ts))          = "ISet";
str atype2javatype(alrel(AType ts))         = "IList";
str atype2javatype(atuple(AType ts))        = "ITuple";
str atype2javatype(amap(AType d, AType r))  = "IMap";

str atype2javatype(afunc(AType ret, list[AType] formals, list[Keyword] kwFormals))
                                            = "TypedFunctionInstance0\<IValue\>"
                                              when isEmpty(formals);
str atype2javatype(afunc(AType ret, list[AType] formals, list[Keyword] kwFormals))
                                            = "TypedFunctionInstance<size(formals)>\<IValue, <intercalate(", ", ["IValue" | _ <- formals])>\>"
                                              when !isEmpty(formals);
 
str atype2javatype(anode(list[AType fieldType] fields)) 
                                            = "INode";
str atype2javatype(aadt(str adtName, list[AType] parameters, SyntaxRole syntaxRole)) 
                                            = "IConstructor";

str atype2javatype(t: acons(AType adt, list[AType fieldType] fields, lrel[AType fieldType, Expression defaultExp] kwFields))
                                            = "IConstructor";
                 
str atype2javatype(aparameter(str pname, AType bound)) 
                                            = atype2javatype(bound);
str atype2javatype(areified(AType atype))   = "IConstructor";

str atype2javatype(avalue())                = "IValue";
str atype2javatype(avoid())                 = "void";

str atype2javatype(tvar(_))                 = "IValue";

str atype2javatype(\start(AType t))         = atype2javatype(t);

str atype2javatype(overloadedAType(rel[loc, IdRole, AType] overloads))
    = atype2javatype(lubList(toList(overloads<2>)));


default str atype2javatype(AType t) = "ITree"; //"IConstructor"; // This covers all parse tree related constructors

/*****************************************************************************/
/*  Convert AType to a descriptor that can be used in a Java identifier      */
/*****************************************************************************/

str atype2idpart(AType t, JGenie jg) {
    str convert(avoid(), bool useAccessor = true)                 = "void";
    str convert(abool(), bool useAccessor = true)                 = "bool";
    str convert(aint(), bool useAccessor = true)                  = "int";
    str convert(areal(), bool useAccessor = true)                 = "real";
    str convert(arat(), bool useAccessor = true)                  = "rat";
    str convert(anum(), bool useAccessor = true)                  = "num";
    str convert(astr(), bool useAccessor = true)                  = "str";
    str convert(aloc(), bool useAccessor = true)                  = "loc";
    str convert(adatetime(), bool useAccessor = true)             = "datetime";
    str convert(alist(AType t), bool useAccessor = true)          = "list_<convert(t, useAccessor=false)>";
    str convert(aset(AType t), bool useAccessor = true)           = "set_<convert(t, useAccessor=false)>";
    str convert(arel(AType ts), bool useAccessor = true)          = "rel_<convert(ts, useAccessor=false)>";
    str convert(alrel(AType ts), bool useAccessor = true)         = "listrel_<convert(ts, useAccessor=false)>";
    str convert(atuple(AType ts), bool useAccessor = true)        = "tuple_<convert(ts, useAccessor=false)>";
    str convert(amap(AType d, AType r), bool useAccessor = true)  = "map_<convert(d, useAccessor=false)>_<convert(r, useAccessor=false)>";
    
    str convert(afunc(AType ret, list[AType] formals, list[Keyword] kwFormals), bool useAccessor = true)
                                              = "<convert(ret)>_<intercalate("_", [convert(f, useAccessor=false) | f <- formals])>";
    
    str convert(anode(list[AType fieldType] fields), bool useAccessor = true)
                                              = "node";
    
    str convert(a: aadt(str adtName, list[AType] parameters, SyntaxRole syntaxRole), bool useAccessor = true){
        return "<useAccessor ? jg.getATypeAccessor(a) : ""><getJavaName(adtName)>";
    }
                                                  
    str convert(t:acons(AType adt, list[AType fieldType] fields, lrel[AType fieldType, Expression defaultExp] kwFields), bool useAccessor = true){
        ext = "<getJavaName(adt.adtName, completeId=false)><t.label? ? "_" + getJavaName(getUnqualifiedName(t.label), completeId=false) : "">_<intercalate("_", [convert(f, useAccessor=false) | f <- fields])>";
        return "<useAccessor ? jg.getATypeAccessor(t) : ""><ext>";
    }
    
    str convert(overloadedAType(rel[loc, IdRole, AType] overloads), bool useAccessor = true){
        resType = avoid();
        formalsType = avoid();
        for(<_, _, tp> <- overloads){
            resType = alub(resType, getResult(tp));
            formalsType = alub(formalsType, atypeList(getFormals(tp)));
        }
        ftype = atypeList(_) := formalsType ? afunc(resType, formalsType.atypes, []) : afunc(resType, [formalsType], []);
        return convert(ftype);
    }
    
    str convert(aprod(AProduction production), bool useAccessor = true){
        return "aprod";
    
    }
    
    str convert(atypeList(list[AType] ts), bool useAccessor = true) 
                                              = intercalate("_", [convert(t, useAccessor=false) | t <- ts]);
    
    str convert(aparameter(str pname, AType bound), bool useAccessor = true) 
                                              = "P<avalue() := bound ? "" : convert(bound)>"; 
    str convert(areified(AType atype), bool useAccessor = true)   = "reified_<convert(atype)>";
    str convert(avalue())                = "value";
    
    str convert(\lit(str s), bool useAccessor = true)             = "lit(\"<s>\")";
    str convert(\empty(), bool useAccessor = true)                = "empty";
    str convert(\opt(AType atype), bool useAccessor = true)       = "opt_<convert(atype)>";
    str convert(\iter(AType atype), bool useAccessor = true)      = "iter_<convert(atype)>"; 
    str convert(\iter-star(AType atype), bool useAccessor = true) = "iter_star_<convert(atype)>"; 
    str convert(\iter-seps(AType atype, list[AType] separators), bool useAccessor = true)
                                              = "iter_seps_<convert(atype)>"; 
    str convert(\iter-star-seps(AType atype, list[AType] separators), bool useAccessor = true)
                                              = "iter_star_seps_<convert(atype)>"; 
    str convert(\alt(set[AType] alternatives), bool useAccessor = true)
                                              = "alt_"; //TODO
    str convert(\seq(list[AType] atypes), bool useAccessor = true)= "seq_";  //TODO
    str convert(\start(AType atype), bool useAccessor = true)        = "start_<convert(atype)>";
    str convert(\conditional(AType atype, set[ACondition] conditions), bool useAccessor = true)
        = convert(atype);
    
    default str convert(AType t, bool useAccessor = true) { throw "convert: cannot handle <t>"; }
    
    return convert(t);

}
//
///*****************************************************************************/
///*  Convert an AType to an IValue (i.e., reify the AType)                    */
///*****************************************************************************/
//
//str lab(AType t) = t.label? ? value2IValue(t.label) : "";
//str lab2(AType t) = t.label? ? ", <value2IValue(t.label)>" : "";
//
//bool isBalanced(str s){
//    pars = 0;
//    brackets = 0;
//    curlies = 0;
//    for(int i <- [0..size(s)]){
//        switch(s[i]){
//            case "(": pars += 1;
//            case ")": { if(pars == 0) return false; pars -= 1; }
//            
//            case "[": brackets += 1;
//            case "]": { if(brackets == 0) return false; brackets -= 1; }
//            
//            case "{": curlies += 1;
//            case "}": { if(curlies == 0) return false; curlies -= 1; }
//        }
//    }
//    return pars == 0 && brackets == 0 && curlies == 0;
//}

//// Wrapper thats checks for balanced output
//str atype2IValue(AType t,  map[AType, set[AType]] defs){
//    res = atype2IValue1(t, defs);
//    if(!isBalanced(res)) throw "atype2IValue: unbalanced, <t>, <res>";
//    return res; 
//}
//
//str lbl(AType at) = at.label? ? "(\"<at.label>\"" : "(";
//
//str atype2IValue1(at:avoid(), _)              = "$avoid<lbl(at)>)";
//str atype2IValue1(at:abool(), _)              = "$abool<lbl(at)>)";
//str atype2IValue1(at:aint(), _)               = "$aint<lbl(at)>)";
//str atype2IValue1(at:areal(), _)              = "$areal<lbl(at)>)";
//str atype2IValue1(at:arat(), _)               = "$arat<lbl(at)>)";
//str atype2IValue1(at:anum(), _)               = "$anum<lbl(at)>)";
//str atype2IValue1(at:astr(), _)               = "$astr<lbl(at)>)";
//str atype2IValue1(at:aloc(), _)               = "$aloc<lbl(at)>)";
//str atype2IValue1(at:adatetime(), _)          = "$adatetime<lbl(at)>)";
//
//// TODO handle cases with label
//str atype2IValue1(at:alist(AType t), map[AType, set[AType]] defs)          
//    = "$alist(<atype2IValue(t, defs)><lab2(at)>)";
//str atype2IValue1(at:abag(AType t), map[AType, set[AType]] defs)           
//    = "$abag(<atype2IValue(t, defs)><lab2(at)>)";
//str atype2IValue1(at:aset(AType t), map[AType, set[AType]] defs)           
//    = "$aset(<atype2IValue(t, defs)><lab2(at)>)";
//str atype2IValue1(at:arel(AType ts), map[AType, set[AType]] defs)          
//    = "$arel(<atype2IValue(ts, defs)><lab2(at)>)";
//str atype2IValue1(at:alrel(AType ts), map[AType, set[AType]] defs)         
//    = "$alrel(<atype2IValue(ts, defs)><lab2(at)>)";
//
//str atype2IValue1(at:atuple(AType ts), map[AType, set[AType]] defs)        
//    = "$atuple(<atype2IValue(ts, defs)><lab2(at)>)";
//str atype2IValue1(at:amap(AType d, AType r), map[AType, set[AType]] defs)  
//    = "$amap(<atype2IValue(d, defs)>,<atype2IValue(r, defs)><lab2(at)>)"; // TODO: complete from here
//
//str atype2IValue1(at:afunc(AType ret, list[AType] formals, list[Keyword] kwFormals), map[AType, set[AType]] defs)
//    = "<atype2IValue(ret, defs)>_<intercalate("_", [atype2IValue(f,defs) | f <- formals])>";
//str atype2IValue1(at:anode(list[AType fieldType] fields), map[AType, set[AType]] defs) 
//    = "$anode(<lab(at)>)";
//str atype2IValue1(at:aadt(str adtName, list[AType] parameters, SyntaxRole syntaxRole), map[AType, set[AType]] defs)
//    = "$aadt(<value2IValue(adtName)>, <atype2IValue(parameters,defs)>, <getName(syntaxRole)>)";
//str atype2IValue1(at:acons(AType adt, list[AType fieldType] fields, lrel[AType fieldType, Expression defaultExp] kwFields), map[AType, set[AType]] defs)
//    = "$acons(<atype2IValue(adt, defs)>, <atype2IValue(fields, defs)>, <atype2IValue(kwFields,defs)><lab2(at)>)";
//str atype2IValue1(overloadedAType(rel[loc, IdRole, AType] overloads), map[AType, set[AType]] defs){
//    resType = avoid();
//    formalsType = avoid();
//    for(<_, _, tp> <- overloads){
//        resType = alub(resType, getResult(tp));
//        formalsType = alub(formalsType, atypeList(getFormals(tp)));
//    }
//    ftype = atypeList(_) := formalsType ? afunc(resType, formalsType.atypes, []) : afunc(resType, [formalsType], []);
//    return atype2IValue(ftype, defs);
//}
//
//str atype2IValue1(at:aparameter(str pname, AType bound), map[AType, set[AType]] defs)
//    = "$aparameter(<atype2IValue(bound,defs)>)"; 
//    
//str atype2IValue1(at:aprod(AProduction production), map[AType, set[AType]] defs) {
//    return "$aprod(<aprod2IValue(production, defs)>)";
//}
//str atype2IValue1(at:areified(AType atype), map[AType, set[AType]] definitions) 
//    = "$reifiedAType((IConstructor) <atype2IValue(atype, definitions)>, <defs(definitions)>)";
//str atype2IValue1(at:avalue(), _)               
//     = "$avalue(<lab(at)>)";
////default str atype2IValue1(AType t, map[AType, set[AType]] defs) { throw "atype2IValue1: cannot handle <t>"; }
//
//str atype2IValue(list[AType] ts, map[AType, set[AType]] defs) 
//    = "$VF.list(<intercalate(", ", [atype2IValue(t,defs) | t <- ts])>)";
//str atype2IValue(lrel[AType fieldType,Expression defaultExp] ts, map[AType, set[AType]] defs) 
//    = "$VF.list(<intercalate(", ", [atype2IValue(t.fieldType,defs) | t <- ts])>)";
//
//str atype2IValue(set[AType] ts, map[AType, set[AType]] defs) 
//    = "$VF.set(<intercalate(", ", [atype2IValue(t,defs) | t <- ts])>)";
//
//str atype2IValue(atypeList(list[AType] atypes), map[AType, set[AType]] defs) 
//    = "$VF.list(<intercalate(", ", [atype2IValue(t,defs) | t <- atypes])>)";
//    
//str defs(map[AType, set[AType]] defs) {
//    res = "$buildMap(<intercalate(", ", ["<atype2IValue(k,defs)>, $VF.set(<intercalate(", ", [ atype2IValue(elem,defs) | elem <- defs[k] ])>)" | k <- defs ])>)";
//    return res;
//}

/*****************************************************************************/
/*  Convert a Tree (and its constituent types) to an IValue                  */
/*****************************************************************************/

//// Wrappers that check for balanced output
//private str assoc2IValue(Associativity t){
//    res = assoc2IValue1(t);
//    if(!isBalanced(res)) throw "assoc2IValue1: unbalanced, <t>, <res>";
//    return res; 
//}

//private str attr2IValue(Attr t){
//    res = attr2IValue1(t);
//    if(!isBalanced(res)) throw "attr2IValue1: unbalanced, <t>, <res>";
//    return res; 
//}
//
//private str tree2IValue(Tree t,  map[AType, set[AType]] defs){
//    res = tree2IValue1(t, defs);
//    if(!isBalanced(res)) throw "tree2IValue1: unbalanced, <t>, <res>";
//    return res; 
//}

//private str prod2IValue(Production t,  map[AType, set[AType]] defs){
//    res = prod2IValue1(t, defs);
//    if(!isBalanced(res)) throw "tree2IValue1: unbalanced, <t>, <res>";
//    return res; 
//}

//private str aprod2IValue(AProduction t,  map[AType, set[AType]] defs){
//    res = aprod2IValue1(t, defs);
//    if(!isBalanced(res)) throw "tree2IValue1: unbalanced, <t>, <res>";
//    return res; 
//}

//private str cond2IValue(Condition c, map[AType, set[AType]] defs){
//    res = cond2IValue1(c, defs);
//    if(!isBalanced(res)) throw "cond2IValue1: unbalanced, <c>, <res>";
//    return res; 
//}

//private str charrange2IValue(CharRange t){
//    res = charrange2IValue1(t);
//    if(!isBalanced(res)) throw "charrange2IValue1: unbalanced, <t>, <res>";
//    return res; 
//}

// ---- Associativity ---------------------------------------------------------

//private str assoc2IValue1(\left()) = "left()";
//private str assoc2IValue1(\right()) = "right()";
//private str assoc2IValue1(\assoc()) = "assoc()";
//private str assoc2IValue1(\non-assoc()) = "non_assoc()";

// ---- Attr ------------------------------------------------------------------

//private str attr2IValue1(\tag(value v)) 
//    = "tag(<value2IValue(v)>)";
//private str attr2IValue1(\assoc(Associativity \assoc)) 
//    = "assoc(<assoc2IValue(\assoc)>)";
//private str attr2IValue1(\bracket())
//    = "bracket())";

// ---- Tree ------------------------------------------------------------------

/*&*/
//private str tree2IValue1(tr:appl(Production prod, list[Tree] args), map[AType, set[AType]] defs)
//    = tr.src? ? "appl(<prod2IValue(prod, defs)>, <tree2IValue(args, defs)>, <value2IValue(tr.src)>)" //<<
//              : "appl(<prod2IValue(prod, defs)>, <tree2IValue(args, defs)>)";                         //<<
//
//private str tree2IValue1(cycle(Symbol asymbol, int cycleLength), map[AType, set[AType]] defs)
//    = "cycle(<atype2IValue(symbol2atype(asymbol), defs)>, <value2IValue(cycleLength)>)";
//
//private str tree2IValue1(amb(set[Tree] alternatives), map[AType, set[AType]] defs)
//    = "amb(<tree2IValue(alternatives,defs)>)";
// 
//private str tree2IValue1(char(int character), map[AType, set[AType]] _defs)
//    = "tchar(<value2IValue(character)>)";
    
// ---- SyntaxRole ------------------------------------------------------------

//private str tree2IValue1(SyntaxRole sr, map[AType, set[AType]] defs) = "<sr>";
   
// ---- AProduction -----------------------------------------------------------

///*&*/
//private str tree2IValue1(\choice(AType def, set[AProduction] alternatives), map[AType, set[AType]] defs)
//    = "choice(<atype2IValue(def, defs)>, <tree2IValue(alternatives, defs)>)";
//
//private str prod2IValue1(tr:prod(Symbol def, list[Symbol] symbols), map[AType, set[AType]] defs){
//    base = "prod(<atype2IValue(symbol2atype(def), defs)>, <[atype2IValue(symbol2atype(sym), defs) | sym <- symbols]>, <tree2IValue(tr.attributes, defs)>)";
//    return base;
//    //kwds = tr.attributes? ? ", <tree2IValue(tr.attributes, defs)>" : "";
//    //if(tr.src?) kwds += ", <value2IValue(tr.src)>";
//    //return base + kwds + ")";
//}

//private str prod2IValue1(regular(Symbol def), map[AType, set[AType]] defs)
//    = "regular(<atype2IValue(symbol2atype(def), defs)>)";

//private str tree2IValue1(error(AProduction prod, int dot), map[AType, set[AType]] defs) //<<
//    = "error(<tree2IValue(prod, defs)>, <value2IValue(dot)>)";

//private str tree2IValue1(skipped(), map[AType, set[AType]] defs)
//    = "skipped()";
  
/*&*/  
//private str prod2IValue1(\priority(Symbol def, list[Production] choices), map[AType, set[AType]] defs)
//    = "priority(<atype2IValue(symbol2atype(def), defs)>, <prod2IValue(choices, defs)>)"; //<<
//    
//private str prod2IValue1(\associativity(Symbol def, Associativity \assoc, set[Production] alternatives), map[AType, set[AType]] defs)
//    = "associativity(<atype2IValue(symbol2atype(def), defs)>, <assoc2IValue(\assoc)>, <prod2IValue(alternatives, defs)>)";
//
////private str tree2IValue1(\others(AType def) , map[AType, set[AType]] defs)
////    = "others(<atype2IValue(def, defs)>)";
//
//private str prod2IValue1(\reference(Symbol def, str cons), map[AType, set[AType]] defs)
//    = "reference(<atype2IValue(symbol2atype(def), defs)>, <value2IValue(cons)>)";
    
// ---- CharRange ------------------------------------------------------------
//private str charrange2IValue1(range(int begin, int end))
//    = "range(<value2IValue(begin)>, <value2IValue(end)>)";
    
// ---- AType extensions for parse trees --------------------------------------
//private str atype2IValue1(AType::lit(str string), map[AType, set[AType]] defs)
//    = "lit(<value2IValue(string)>)";
//
//private str atype2IValue1(AType::cilit(str string), map[AType, set[AType]] defs)
//    = "cilit(<value2IValue(string)>)";
///*&*/
//private str atype2IValue1(AType::\char-class(list[ACharRange] ranges), map[AType, set[AType]] defs)
//    = "char_class(<tree2IValue(ranges, defs)>)";   
// 
//private str atype2IValue1(AType::\empty(), map[AType, set[AType]] defs)
//    = "empty()";     
//
//private str atype2IValue1(AType::\opt(AType symbol), map[AType, set[AType]] defs)
//    = "opt(<atype2IValue(symbol, defs)>)";     
//
//private str atype2IValue1(AType::\iter(AType symbol), map[AType, set[AType]] defs)
//    = "iter(<atype2IValue(symbol, defs)>)";     
//
//private str atype2IValue1(AType::\iter-star(AType symbol), map[AType, set[AType]] defs)
//    = "iter_star(<atype2IValue(symbol, defs)>)";   
//
//private str atype2IValue1(AType::\iter-seps(AType symbol, list[AType] separators), map[AType, set[AType]] defs)
//    = "iter_seps(<atype2IValue(symbol, defs)>, <atype2IValue(separators, defs)>)";     
// 
//private str atype2IValue1(AType::\iter-star-seps(AType symbol, list[AType] separators), map[AType, set[AType]] defs)
//    = "iter_star_seps(<atype2IValue(symbol, defs)>, <atype2IValue(separators, defs)>)";   
//    
//private str atype2IValue1(AType::\alt(set[AType] alternatives) , map[AType, set[AType]] defs)
//    = "alt(<atype2IValue(alternatives, defs)>)";     
//private str atype2IValue1(AType::\seq(list[AType] symbols) , map[AType, set[AType]] defs)
//    = "seq(<atype2IValue(symbols, defs)>)";     
// 
//private str atype2IValue1(AType::\start(AType symbol), map[AType, set[AType]] defs)
//    = "start(<atype2IValue(symbol, defs)>)";   
//
//private str atype2IValue1(AType::\conditional(AType symbol, set[ACondition] conditions), map[AType, set[AType]] defs)
//    = "conditional(<atype2IValue(symbol, defs)>, <cond2IValue(conditions, defs)>)";   
    
// ---- Condition ------------------------------------------------------------

//private str cond2IValue1(\follow(Symbol symbol), map[AType, set[AType]] defs)
//    = "follow(<atype2IValue(symbol2atype(symbol), defs)>)";   
//
//private str cond2IValue1(\not-follow(Symbol symbol), map[AType, set[AType]] defs)
//    = "not_follow(<atype2IValue(symbol2atype(symbol), defs)>)";
//    
//private str cond2IValue1(\precede(Symbol symbol), map[AType, set[AType]] defs)
//    = "precede(<atype2IValue(symbol2atype(symbol), defs)>)";  
//
//private str cond2IValue1(\not-precede(Symbol symbol), map[AType, set[AType]] defs)
//    = "not_precede(<atype2IValue(symbol2atype(symbol), defs)>)"; 
//    
//private str cond2IValue1(\delete(Symbol symbol), map[AType, set[AType]] defs)
//    = "delete(<atype2IValue(symbol2atype(symbol), defs)>)"; 
    
//private str cond2IValue1(\at-column(int column), map[AType, set[AType]] defs)
//    = "at_column(<value2IValue(column)>)";  
//    
//private str cond2IValue1(\begin-of-line(), map[AType, set[AType]] defs)
//    = "begin_of_line()";
//    
//private str cond2IValue1(\end-of-line(), map[AType, set[AType]] defs)
//    = "end_of_line()"; 
//    
//private str cond2IValue1(\except(str label), map[AType, set[AType]] defs)
//    = "except(<value2IValue(label)>)";              
                  
//---- list/set wrappers for some parse tree constructs

//private str tree2IValue(list[Tree] trees, map[AType, set[AType]] defs)
//    = "$VF.list(<intercalate(", ", [ tree2IValue(tr, defs) | tr <- trees ])>)";
//    
//private str tree2IValue(set[Tree] trees, map[AType, set[AType]] defs)
//    = "$VF.set(<intercalate(", ", [ tree2IValue(tr, defs) | tr <- trees ])>)";
//  
// /*&*/  
//private str prod2IValue(set[Production] prods, map[AType, set[AType]] defs)
//    = "$VF.set(<intercalate(", ", [ prod2IValue(pr, defs) | pr <- prods ])>)";
//
//private str prod2IValue(list[Production] prods, map[AType, set[AType]] defs)
//    = "$VF.set(<intercalate(", ", [ prod2IValue(pr, defs) | pr <- prods ])>)";
//    
//private str attr2IValue(set[Attr] attrs)
//    = "$VF.set(<intercalate(", ", [ attr2IValue(a) | a <- attrs ])>)";   
//    
//private str cond2IValue(set[Condition] conds, map[AType, set[AType]] defs)
//    = "$VF.set(<intercalate(", ", [ cond2IValue(c, defs) | c <- conds ])>)"; //<<
//    
//private str charrange2IValue(list[CharRange] ranges)
//    = "$VF.list(<intercalate(", ", [ charrange2IValue(r) | r <- ranges ])>)"; 
// 

/*****************************************************************************/
/*  Get the outermost type of an AType (used for names of primitives)        */
/*****************************************************************************/

str getOuter(avoid())                 = "avoid";
str getOuter(abool())                 = "abool";
str getOuter(aint())                  = "aint";
str getOuter(areal())                 = "areal";
str getOuter(arat())                  = "arat";
str getOuter(anum())                  = "anum";
str getOuter(astr())                  = "astr";
str getOuter(aloc())                  = "aloc";
str getOuter(adatetime())             = "adatetime";
str getOuter(alist(AType t))          = "alist";
str getOuter(aset(AType t))           = "aset";
str getOuter(arel(AType ts))          = "aset";
str getOuter(alrel(AType ts))         = "alist";
str getOuter(atuple(AType ts))        = "atuple";
str getOuter(amap(AType d, AType r))  = "amap";
str getOuter(afunc(AType ret, list[AType] formals, list[Keyword] kwFormals))
                                      = "afunc";
str getOuter(anode(list[AType fieldType] fields)) 
                                      = "anode";
str getOuter(aadt(str adtName, list[AType] parameters, SyntaxRole syntaxRole)) = "aadt";
str getOuter(t:acons(AType adt, list[AType fieldType] fields, lrel[AType fieldType, Expression defaultExp] kwFields))
                                      = "acons";
str getOuter(aparameter(str pname, AType bound)) 
                                      = getOuter(bound);
str getOuter(avalue())                = "avalue";
default str getOuter(AType t)         = "avalue";

// ----

// TODO cover all cases
// Escape a string using Java escape conventions

str escapeForJ(str s){
   n = size(s);
   i = 0;
   res = "";
   while(i < n){
    c = s[i];
    switch(c){
        case "\b": res += "\\b";
        case "\t": res += "\\t";
        case "\n": res += "\\n";
        case "\r": res += "\\r";
        case "\a0C": res += "\\f";  // formfeed
        case "\'": res += "\\\'";
        case "\"": res += "\\\"";
        case "\\" : res += "\\\\";
        //case "\\": if(i+1 < n){ 
        //                c1 = s[i+1];
        //                i += 1;
        //                if(c1 == "\\"){
        //                    res += "<c><c1><c><c1>";
        //                } else if(c1 in {"b","f","t",/*"n",*/"r","\'", "\""}){
        //                    res += "<c><c><c><c1>";
        //                } else {
        //                    res += "<c><c><c1>";
        //                }
        //            } else {
        //                res += "<c><c>";
        //            }
        default: res +=  c;
     }
     i += 1;
   }
   return res;
}

str escapeForJRegExp(str s){
   n = size(s);
   i = 0;
   res = "";
   while(i < n){
    c = s[i];
    switch(c){
        case "\b": res += "\\b";
        case "\t": res += "\\t";
        case "\n": res += "\\n";
        case "\r": res += "\\r";
        case "\a0C": res += "\\f";  // formfeed
        case "\'": res += "\\\'";
        case "\"": res += "\\\"";
        //case "(": res += "\\(";
        //case ")": res += "\\)";
        //case "[": res += "\\[";
        //case "]": res += "\\]";
        //case ".": res += "\\.";
        //case "$": res += "\\$";
        //case "^": res += "\\^";
        case "\\": if(i+1 < n){ 
                        c1 = s[i+1];
                        i += 1;
                        if(c1 == "\\"){
                            res += "<c><c1><c><c1>";
                        } else if (c1 == "/"){
                            res += "/";
                        } else  if(c1 in {"b","f","t","n","r","\'", "\""}){
                            res += "<c><c1>";
                        } else {
                            res += "<c><c><c1>";
                        }
                    } else {
                        res += "<c><c>";
                    }
        default: res +=  c;
     }
     i += 1;
   }
   return res;
}

str inlineComment(value v){
    s = "<v>";
    q = str _ := v ? "\"" : "";
    return "/*<q><replaceAll(s, "*/", "*\\/")><q>*/";
}
    
/*****************************************************************************/
/*  Convert a Rascal value to the equivalent IValue                          */
/*****************************************************************************/

str value2IValue(value x) = value2IValue(x, ());
str value2IValue(value x, map[value, int] constants) = doValue2IValue(x, constants);

str value2IValueRec(value x, map[value, int] constants) = "((<value2outertype(x)>)$constants.get(<constants[x]>)<inlineComment(x)>)" when constants[x]?;
default str value2IValueRec(value x, map[value, int] constants) = doValue2IValue(x, constants);

str doValue2IValue(bool b, map[value, int] constants) = "$VF.bool(<b>)";
str doValue2IValue(int n, map[value, int] constants) = "$VF.integer(\"<n>\")";
str doValue2IValue(real r, map[value, int] constants) = "$VF.real(<r>)";
str doValue2IValue(rat rt, map[value, int] constants) = "$VF.rational(\"<rt>\")";
str doValue2IValue(str s, map[value, int] constants) = "$VF.string(\"<escapeForJ(s)>\")";

str doValue2IValue(loc l, map[value, int] constants) {
    base = "$create_aloc($VF.string(\"<l.uri>\"))";
    return l.offset? ? "$VF.sourceLocation(<base>, <l.offset>, <l.length>, <l.begin.line>, <l.end.line>, <l.begin.column>, <l.end.column>)"
                      : base;
}

str doValue2IValue(datetime dt, map[value, int] constants) {
    if(dt.isDateTime)
        return "$VF.datetime(<dt.year>, <dt.month>, <dt.day>, <dt.hour>, <dt.minute>, <dt.second>, <dt.millisecond>, <dt.timezoneOffsetHours>, <dt.timezoneOffsetMinutes>)";
    if(dt.isDate)
        return "$VF.date(<dt.year>, <dt.month>, <dt.day>)";
    return "$VF.time(<dt.hour>, <dt.minute>, <dt.second>, <dt.millisecond>)";
}

str doValue2IValue(list[&T] lst, map[value, int] constants) = "$VF.list(<intercalate(", ", [value2IValueRec(elem, constants) | elem <- lst ])>)";
str doValue2IValue(set[&T] st, map[value, int] constants) = "$VF.set(<intercalate(", ", [value2IValueRec(elem, constants) | elem <- st ])>)";

str doValue2IValue(tuple[&A] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>)";
str doValue2IValue(tuple[&A,&B] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>)";
str doValue2IValue(tuple[&A,&B,&C] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>, <value2IValueRec(tup[2], constants)>)";
str doValue2IValue(tuple[&A,&B,&C,&D] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>, <value2IValueRec(tup[2], constants)>, <value2IValueRec(tup[3], constants)>)";
str doValue2IValue(tuple[&A,&B,&C,&D,&E] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>, <value2IValueRec(tup[2], constants)>, <value2IValueRec(tup[3], constants)>, <value2IValueRec(tup[4], constants)>)";
str doValue2IValue(tuple[&A,&B,&C,&D,&E,&F] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>, <value2IValueRec(tup[2], constants)>, <value2IValueRec(tup[3], constants)>, <value2IValueRec(tup[4], constants)>, <value2IValueRec(tup[5], constants)>)";
str doValue2IValue(tuple[&A,&B,&C,&D,&E,&F,&G] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>, <value2IValueRec(tup[2], constants)>, <value2IValueRec(tup[3], constants)>, <value2IValueRec(tup[4], constants)>, <value2IValueRec(tup[5], constants)>, <value2IValueRec(tup[6], constants)>)";
str doValue2IValue(tuple[&A,&B,&C,&D,&E,&F,&G,&H] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>, <value2IValueRec(tup[2], constants)>, <value2IValueRec(tup[3], constants)>, <value2IValueRec(tup[4], constants)>, <value2IValueRec(tup[5], constants)>, <value2IValueRec(tup[6], constants)>, <value2IValueRec(tup[7], constants)>)";
str doValue2IValue(tuple[&A,&B,&C,&D,&E,&F,&G,&H,&I] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>, <value2IValueRec(tup[2], constants)>, <value2IValueRec(tup[3], constants)>, <value2IValueRec(tup[4], constants)>, <value2IValueRec(tup[5], constants)>, <value2IValueRec(tup[6], constants)>, <value2IValueRec(tup[7], constants)>, <value2IValueRec(tup[8], constants)>)";
str doValue2IValue(tuple[&A,&B,&C,&D,&E,&F,&G,&H,&I,&J] tup, map[value, int] constants) = "$VF.tuple(<value2IValueRec(tup[0], constants)>, <value2IValueRec(tup[1], constants)>, <value2IValueRec(tup[2], constants)>, <value2IValueRec(tup[3], constants)>, <value2IValueRec(tup[4], constants)>, <value2IValueRec(tup[5], constants)>, <value2IValueRec(tup[6], constants)>, <value2IValueRec(tup[7], constants)>, <value2IValueRec(tup[8], constants)>, <value2IValueRec(tup[9], constants)>)";

str doValue2IValue(map[&K,&V] mp, map[value, int] constants) = "$buildMap(<intercalate(", ", ["<value2IValueRec(k, constants)>, <value2IValueRec(mp[k], constants)>" | k <- mp ])>)";

str doValue2IValue(type[&T] typeValue, map[value, int] constants) {
   return "$RVF.reifiedType(<value2IValueRec(typeValue.symbol, constants)>,<value2IValueRec(typeValue.definitions, constants)>)";
}

// the builtin reified type representations (Symbol, Production) are not necessarily declared in the current scope, so
// we lookup their constructors in the RascalValueFactory hand-written fields:
str doValue2IValue(Symbol sym, map[value, int] constants) {
   return "$RVF.constructor(RascalValueFactory.Symbol_<toRascalValueFactoryName(getName(sym))><if (getChildren(sym) != []){>,<}> <intercalate(",", [value2IValueRec(child, constants) | child <- getChildren(sym)])>)";
}

str doValue2IValue(Production sym, map[value, int] constants) {
   return "$RVF.constructor(RascalValueFactory.Production_<toRascalValueFactoryName(getName(sym))><if (getChildren(sym) != []){>,<}> <intercalate(",", [value2IValueRec(child, constants) | child <- getChildren(sym)])>)";
}

str doValue2IValue(Attr sym, map[value, int] constants) {
   return "$RVF.constructor(RascalValueFactory.Attr_<toRascalValueFactoryName(getName(sym))><if (getChildren(sym) != []){>,<}> <intercalate(",", [value2IValueRec(child, constants) | child <- getChildren(sym)])>)";
}

str doValue2IValue(Associativity sym, map[value, int] constants) {
   return "$RVF.constructor(RascalValueFactory.Associativity_<toRascalValueFactoryName(getName(sym))><if (getChildren(sym) != []){>,<}> <intercalate(",", [value2IValueRec(child, constants) | child <- getChildren(sym)])>)";
}

str doValue2IValue(CharRange sym, map[value, int] constants) {
   return "$RVF.constructor(RascalValueFactory.CharRange_<toRascalValueFactoryName(getName(sym))><if (getChildren(sym) != []){>,<}> <intercalate(",", [value2IValueRec(child, constants) | child <- getChildren(sym)])>)";
}

str doValue2IValue(Production sym, map[value, int] constants) {
   return "$RVF.constructor(RascalValueFactory.Production_<toRascalValueFactoryName(getName(sym))><if (getChildren(sym) != []){>,<}> <intercalate(",", [value2IValueRec(child, constants) | child <- getChildren(sym)])>)";
}

str toRascalValueFactoryName(str consName) = capitalize(visit(consName) {
    case /\-<l:[a-z]>/ => capitalize(l) 
});

str doValue2IValue(char(int i), map[value, int] constants)  = "$RVF.character(<i>)";

str doValue2IValue(Tree t:appl(Production prod, list[Tree] args), map[value, int] constants) {
    childrenContrib = isEmpty(args) ? "" : ", <intercalate(", ", [ value2IValueRec(child, constants) | child <- args ])>";
    return "$RVF.appl(<value2IValueRec(prod, constants)> <childrenContrib>)";
}

default str doValue2IValue(node nd, map[value, int] constants) {
    name = getName(nd);
   
    children = getChildren(nd);
    childrenContrib = isEmpty(children) ? "" : ", <intercalate(", ", [ value2IValueRec(child, constants) | child <- getChildren(nd) ])>";
   
    if(name in {"follow", "not-follow", "precede", "not-precede", "delete", "at-column", "begin-of-line", "end-of-line", "except"}){
         childrenContrib = intercalate(", ", [ value2IValueRec(child, constants) | child <- children ]);
         return "$RVF.constructor(RascalValueFactory.Condition_<toRascalValueFactoryName(name)><if (children != []){>,<}><childrenContrib>)";
       
    } else {
        childrenContrib = isEmpty(children) ? "" : ", <intercalate(", ", [ value2IValueRec(child, constants) | child <- children ])>";
        kwparams = getKeywordParameters(nd);
        kwparamsContrib = isEmpty(kwparams) ? "" : ", keywordParameters=<kwparams>";
        name = isEmpty(name) ? "\"\"" : (name[0] == "\"" ? name : "\"<name>\"");
        return "$VF.node(<name><childrenContrib><kwparamsContrib>)";
    }
}

str doValue2IValue(aadt(str adtName, list[AType] parameters, contextFreeSyntax()), map[value, int] constants) 
    = "$RVF.constructor(RascalValueFactory.Symbol_Sort, $VF.string(\"<adtName>\"))";

str doValue2IValue(aadt(str adtName, list[AType] parameters, SyntaxRole syntaxRole), map[value, int] constants) = adtName;

str doValue2IValue(acons(AType adt,
                list[AType fieldType] fields,
                lrel[AType fieldType, Expression defaultExp] kwFields), map[value, int] constants)
                 = "IConstructor";

str doValue2IValue(t:avoid(), map[value, int] constants) { throw "value2IValue: cannot handle <t>"; }
str doValue2IValue(t:areified(AType atype), map[value, int] constants) { throw "value2IValue: cannot handle <t>"; }
default str doValue2IValue(value v, map[value, int] constants) { throw "value2IValue: cannot handle <v>"; }

/*****************************************************************************/
/*  Convert a Rascal value to Java equivalent of its outer type              */
/*****************************************************************************/

str value2outertype(int _) = "IInteger";
str value2outertype(bool _) = "IBool";
str value2outertype(real _) = "IReal";
str value2outertype(rat _) = "IRational";
str value2outertype(str _) = "IString";

str value2outertype(Tree _) = "IConstructor";
str value2outertype(Symbol _) = "IConstructor";
str value2outertype(Production _) = "IConstructor";
default str value2outertype(node _) = "INode";
str value2outertype(loc _) = "ISourceLocation";
str value2outertype(datetime _) = "IDateTime";
str value2outertype(list[&T] _) = "IList";
str value2outertype(set[&T] _) = "ISet";
str value2outertype(map[&K,&V] _) = "IMap";
str value2outertype(atuple(AType _)) = "ITuple"; // ?? this is not a value
str value2outertype(tuple[&A] _) = "ITuple";
str value2outertype(tuple[&A,&B] _) = "ITuple";
str value2outertype(tuple[&A,&B,&C] _) = "ITuple";
str value2outertype(tuple[&A,&B,&C,&D] _) = "ITuple";
str value2outertype(tuple[&A,&B,&C,&D,&E] _) = "ITuple";
str value2outertype(tuple[&A,&B,&C,&D,&E,&F] _) = "ITuple";
str value2outertype(tuple[&A,&B,&C,&D,&E,&F,&G] _) = "ITuple";
str value2outertype(tuple[&A,&B,&C,&D,&E,&F,&G,&H] _) = "ITuple";
str value2outertype(tuple[&A,&B,&C,&D,&E,&F,&G,&H,&I] _) = "ITuple";
str value2outertype(tuple[&A,&B,&C,&D,&E,&F,&G,&H,&I,&J] _) = "ITuple";

str value2outertype(amap(AType _, AType _)) = "IMap";
str value2outertype(arel(AType _)) = "IRelation\<ISet\>";
str value2outertype(alrel(AType_)) = "IRelation\<IList\>";

str value2outertype(aadt(str adtName, list[AType] _, SyntaxRole _)) = adtName;

str value2outertype(acons(AType adt,
                list[AType fieldType] fields,
                lrel[AType fieldType, Expression defaultExp] kwFields))
                 = "IConstructor";
str value2outertype(areified(AType atype)) = "IConstructor";
default str value2outertype(AType t) = "IValue";

/*******************************************************************************/
/*  Convert an AType to an equivalent type ("VType") in the Vallang type store */
/*******************************************************************************/

str refType(AType t, JGenie jg, bool inTest)
    = inTest ? "$me.<jg.shareType(t)>" : jg.shareType(t);
    
str atype2vtype(aint(), JGenie jg, bool inTest=false) = "$TF.integerType()";
str atype2vtype(abool(), JGenie jg, bool inTest=false) = "$TF.boolType()";
str atype2vtype(areal(), JGenie jg, bool inTest=false) = "$TF.realType()";
str atype2vtype(arat(), JGenie jg, bool inTest=false) = "$TF.rationalType()";
str atype2vtype(astr(), JGenie jg, bool inTest=false) = "$TF.stringType()";
str atype2vtype(anum(), JGenie jg, bool inTest=false) = "$TF.numberType()";
str atype2vtype(anode(list[AType fieldType] fields), JGenie jg, bool inTest=false) = "$TF.nodeType()";
str atype2vtype(avoid(), JGenie jg, bool inTest=false) = "$TF.voidType()";
str atype2vtype(avalue(), JGenie jg, bool inTest=false) = "$TF.valueType()";
str atype2vtype(aloc(), JGenie jg, bool inTest=false) = "$TF.sourceLocationType()";
str atype2vtype(adatetime(), JGenie jg, bool inTest=false) = "$TF.dateTimeType()";
str atype2vtype(alist(AType t), JGenie jg, bool inTest=false) = "$TF.listType(<refType(t, jg, inTest)>)";
str atype2vtype(aset(AType t), JGenie jg, bool inTest=false) = "$TF.setType(<refType(t, jg, inTest)>)";
str atype2vtype(atuple(AType ts), JGenie jg, bool inTest=false) = "$TF.tupleType(<atype2vtype(ts, jg, inTest=inTest)>)";

str atype2vtype(amap(AType d, AType r), JGenie jg, bool inTest=false) {
    return (d.label? && d.label != "_")
             ? "$TF.mapType(<refType(d, jg, inTest)>, \"<d.label>\", <refType(r, jg, inTest)>, \"<r.label>\")"
             : "$TF.mapType(<refType(d, jg, inTest)>,<refType(r, jg, inTest)>)";
}
str atype2vtype(arel(AType t), JGenie jg, bool inTest=false) = "$TF.setType($TF.tupleType(<atype2vtype(t, jg,inTest=inTest)>))";
str atype2vtype(alrel(AType t), JGenie jg, bool inTest=false) = "$TF.listType($TF.tupleType(<atype2vtype(t, jg, inTest=inTest)>))";

str atype2vtype(f:afunc(AType ret, list[AType] formals, list[Keyword] kwFormals), JGenie jg, bool inTest=false){
    vformals = isEmpty(formals) ? "$TF.tupleEmpty()" 
                                : ( (!isEmpty(formals) && any(t <- formals, t.label?)) 
                                        ? "$TF.tupleType(<intercalate(", ", [ *[refType(t, jg, inTest), "\"<t.label>\""] | t <- formals])>)"
                                        : "$TF.tupleType(<intercalate(", ", [ refType(t, jg, inTest) | t <- formals])>)"
                                  );
    vkwformals = isEmpty(kwFormals) ? "$TF.tupleEmpty()" 
                                    : "$TF.tupleType(<intercalate(", ", [ refType(t.fieldType, jg, inTest) | t <- kwFormals])>)"; 
    return "$TF.functionType(<jg.shareType(ret)>, <vformals>, <vkwformals>)";
}


str atype2vtype(a:aadt(str adtName, list[AType] parameters, dataSyntax()), JGenie jg, bool inTest=false)
    = (inTest ? "$me." : "") + "<jg.getATypeAccessor(a)><getADTName(adtName)>";
    
str atype2vtype(aadt(str adtName, list[AType] parameters, contextFreeSyntax()), JGenie jg, bool inTest=false)    
    = "$TF.fromSymbol($RVF.constructor(RascalValueFactory.Symbol_Sort, $VF.string(\"<adtName>\")), $TS, p -\> Collections.emptySet())";
    
str atype2vtype(a:aadt(str adtName, list[AType] parameters, lexicalSyntax()), JGenie jg, bool inTest=false){    
    return (inTest ? "$me." : "") + "<jg.getATypeAccessor(a)><getADTName(adtName)>";
    //return "$TF.constructor($TS, RascalValueFactory.Symbol, \"lex\", $VF.string(\"<adtName>\"))";
}
    
str atype2vtype(aadt(str adtName, list[AType] parameters, keywordSyntax()), JGenie jg, bool inTest=false)    
    = "$TF.constructor($TS, RascalValueFactory.Symbol, \"keywords\", $VF.string(\"<adtName>\"))";
str atype2vtype(a:aadt(str adtName, list[AType] parameters, layoutSyntax()), JGenie jg, bool inTest=false)    
    = (inTest ? "$me." : "") + "<jg.getATypeAccessor(a)><getADTName(adtName)>";
    //= "$TF.constructor($TS, RascalValueFactory.Symbol, \"layout\", $VF.string(\"<adtName>\"))";
                                 
str atype2vtype(c:acons(AType adt,
                list[AType fieldType] fields,
                lrel[AType fieldType, Expression defaultExp] kwFields), JGenie jg, bool inTest=false){
    res = "$TF.constructor(<jg.getATypeAccessor(c)>$TS, <jg.shareType(adt)>, \"<c.label>\"<isEmpty(fields) ? "" : ", "><intercalate(", ", [ *[refType(t, jg, inTest), "\"<t.label>\""] | t <- fields])>)";
    return res;
}
str atype2vtype(aparameter(str pname, AType bound), JGenie jg, bool inTest=false) = "$TF.parameterType(\"<pname>\", <refType(bound, jg, inTest)>)";


str atype2vtype(atypeList(list[AType] atypes), JGenie jg, bool inTest=false)
    = (atypes[0].label? && atypes[0].label != "_")
         ? intercalate(", ", [*[refType(t, jg, inTest), "\"<t.label>\""] | t <- atypes])
         : intercalate(", ", [refType(t, jg, inTest) | t <- atypes]);
                       
str atype2vtype(areified(AType atype), JGenie jg, bool inTest=false) {
    return "$RTF.reifiedType(<refType(atype, jg, inTest)>)";
}

default str atype2vtype(AType t, JGenie jg, bool inTest=false) {
    return "$TF.valueType()";
}