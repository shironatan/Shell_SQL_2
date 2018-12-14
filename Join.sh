#!/bin/bash

#ファイルが存在するか
File(){
	SQLFILE="$1.sql"
	if [ -f $SQLFILE ];
       	then
		echo "$SQLFILEに追記していきます"
	else
		echo "$SQLFILEを新規作成"
	fi
}

#ユーザー新規作成・変更
Change(){
        local file=".my.cnf"
	local username
	local password
	local hostname
	echo "ユーザーを新規作成・変更"
	read -p "ユーザー名 : " username </dev/tty
	read -s -p "パスワード : " password </dev/tty
	echo
	read -p "ホスト名 : " hostname </dev/tty
	#ファイル内にかきこみ
	{ echo "[client]";
		echo "user = $username";
		echo "password = $password";
		echo "host = $hostname";
	} > $file
	echo "新規作成・変更完了"
}

#ログインユーザー選ぶ
Account(){
	local file=".my.cnf"
	local login_user
	if [ ! -e $file ];
	then
		Change
	fi
	echo "/* ログインユーザー */"
	cat $file | grep 'user = ' | awk '{print $3}'
	read -p"ユーザー名を指定[変更:change] : " login_user </dev/tty
	if [ "$login_user" = "change" ];
	then
		Change
		Account
	else
		USER="$login_user"
	fi

}

#MYSQL接続テスト
Connect(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e"select user();"`
	if [ $? -eq 1 ];
	then
                echo "MYSQLに接続できませんでした。"
                exit 1
	else
		echo "MYSQLに接続できました"
		local user_list=`echo $ret | awk '{ print $2; }'`
		echo "$user_listでログインしました"
        fi
}

#所有のDBを返す
Show_DB(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "show databases;"`
	if [ $? -gt 0 ];
	then
		exit 0
	fi
	echo "/* データベース一覧 */"
	ARRAY=($ret)
	unset ARRAY[0]
	Show_array
}
#所有のテーブルからTABLE配列に格納されていないものを配列に格納しShow_array関数を呼ぶ（引数：データベース名）
Show_Table(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;show tables;"`
	if [ $? -gt 0 ]
	then
		echo "存在しないデータベース名です"
		echo "最初からやり直してください"
		exit 1
	fi
	#retからTABLEに格納されているものを削除
	local e
	for e in ${TABLE[@]}
	do
		ret=`echo $ret | sed -e 's/ '$e' / /'`
		ret=`echo $ret | sed -e 's/^'$e' \| '$e'\$//'`
	done
	echo "/* テーブル一覧 */"
	ARRAY=($ret)
	unset ARRAY[0]
	Show_array
}

#存在するテーブル名かチェック(引数:データベース名,テーブル名)
Check_table(){
	local ret
	local file=".my.cnf"
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;select * FROM $2;"`
        if [ $? -gt 0 ]
	then
                echo "存在しないテーブル名です"
                echo "最初からやり直してください"
                exit 1
        fi
}
#存在する項目名かチェック(引数:データベース名,テーブル名,項目名)
Check_colum(){
	local ret
	local file=".my.cnf"
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;select $3 FROM $2;"`
        if [ $? -gt 0 ]
	then
                echo "存在しない項目名です"
                echo "最初からやり直してください"
                exit 1
        fi
}

#テーブル情報を返す(引数:データベース名 テーブル名)
Show_TableInf(){
	local file=".my.cnf"
	local ret
	echo "/* $2テーブルの列情報 */"
	mysql --defaults-extra-file=./$file -u $USER -e "use $1;SHOW COLUMNS FROM $2"
}
#テーブルデータを返す(引数:データベース名 テーブル名)
Show_TableData(){
	local file=".my.cnf"
	local ret
	echo "/* $2テーブルデータ一覧 */"
	mysql --defaults-extra-file=./$file -u $USER -e "use $1;SELECT * FROM $2"
}

#配列の中身を１要素目削除し縦に表示
Show_array(){
	local e	
	for e in "${ARRAY[@]}"
	do
		echo "*** ${e}"
	done
}
#配列の中身を横に表示
Show_array2(){	
	local e
	local data
	for e in "${ARRAY2[@]}"
	do
		data="$data ${e}"
	done
	echo $data
}
#テーブル結合関数(引数：DB名）
JOIN_table(){
	local table
	Show_Table $1
	read -p "メインテーブルを入力：" table </dev/tty
	Check_table $1 $table
	Targ_Colum $1 $table
	TABLE+=($table)
	Show_Table $1
	read -p "結合テーブルを入力[終了：q]：" table </dev/tty
	while [ "$table" != "q" ]
	do
		Check_table $1 $table
		Join_Colum $1 $table
		Targ_Colum $1 $table
		TABLE+=($table)
		Show_Table $1
		read -p "結合テーブルを入力[終了:q]：" table </dev/tty
		echo
	done

	if [ ${#TABLE[@]} -eq 1 ]
	then
		echo "結合テーブル１つ以上は必要です"
		echo "最初からやり直してください"
		exit 1
	fi
}
#結合項目関数(引数：データベース名、結合テーブル名）
Join_Colum(){
	local i=$(( ${#TABLE[@]} - 1 ))
	local F="${TABLE[i]}"
	local D="$2"
	local colum
	Show_TableInf $1 $F
	Show_TableInf $1 $D
	read -p "$Fテーブル結合項目名：" colum
	Check_colum $1 $F $colum
	JOIN_COLUM+=("$F.$colum")
	read -p "$Dテーブル結合項目名：" colum
	Check_colum $1 $D $colum
	JOIN_COLUM+=("$D.$colum")
}
#結合条件関数(引数：データベース名、結合テーブル名）
Targ_Colum(){
	local colum
	Show_TableData $1 $2
	read -p "$2テーブル結合条件項目名[無し/終了:q]：" colum
	while [ "$colum" != "q" ]
	do
		Check_colum $1 $2 $colum
		TARG_COLUM+=($2)
		TARG_COLUM+=($colum)
		read -p "$2テーブル結合条件項目内容：" colum
		TARG_COLUM+=($colum)
		read -p "$2テーブル結合条件項目名[無し/終了:q]：" colum
	done
}
#SQLをつくる(引数：データベース名）
Create_sql(){
	FROM="FROM ${TABLE[0]}"
	SQL_2
	SQL_3
	if [ 0 -eq ${#TARG_COLUM[@]} ] #条件がない場合
	then
		{ echo "use $1;"
			echo "SELECT *"
			echo "$FROM"
			echo -e "$JOIN;"
		} > $SQLFILE
	else
		{ echo "use $1;"
			echo "SELECT *"
			echo "$FROM"
			echo -e "$JOIN"
			echo "$WHERE;"
		} > $SQLFILE
	fi
}
#joinをつくる
SQL_2(){
	local e
	local i=0
	#テーブル用変数
	local j=1
	for e in "${JOIN_COLUM[@]}"
	do
		if [ $i -eq 0 ]
		then
			JOIN="$JOIN_SELECT ${TABLE[j]} ON ${JOIN_COLUM[i]} = ${JOIN_COLUM[i+1]}"
		else
			JOIN="$JOIN\n$JOIN_SELECT ${TABLE[j]} ON ${JOIN_COLUM[i]} = ${JOIN_COLUM[i+1]}"
		fi
		i=$(( $i + 2 ))
		let j++
		if [ $i -eq ${#JOIN_COLUM[@]} ]
		then
			break
		fi
	done
}
#whereをつくる
SQL_3(){
	WHERE="WHERE"
	local e
	local i=0
	for e in "${TARG_COLUM[@]}"
	do
		if [ $i -eq 0 ]
		then
			WHERE="$WHERE ${TARG_COLUM[i]}.${TARG_COLUM[i+1]} = \"${TARG_COLUM[i+2]}\""
		else
			WHERE="$WHERE AND ${TARG_COLUM[i]}.${TARG_COLUM[i+1]} = \"${TARG_COLUM[i+2]}\""
		fi
		i=$(( $i + 3 ))
		if [ $i -eq ${#TARG_COLUM[@]} ]
		then
			break
		fi
	done
}
#JOIN選ぶ
Join(){
	local select
	echo -e "\n結合の種類を選んでください"
	echo "内部結合 : 1"
	echo "左外部結合 : 2"
	read -p "結合の種類：" select </dev/tty
	case "$select" in
		"1" ) JOIN_SELECT="INNER JOIN";;
		"2" ) JOIN_SELECT="LEFT OUTER JOIN";;
		* ) echo -e "存在しない選択です。\n最初からやり直してください。"
			exit 0;;
	esac
	echo
}

echo "SQLファイルを新規作成(結合文)"
read -p "ファイル名を入力 : " SQLFILE </dev/tty
File $SQLFILE
Join
Account
Connect
Show_DB
read -p "データベース名を入力：" Show_DB </dev/tty
JOIN_table $Show_DB
Create_sql $Show_DB
echo "--------------------"
echo "ファイル名：$SQLFILE"
cat $SQLFILE
