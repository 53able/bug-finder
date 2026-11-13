#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = []
# ///
"""コマンドを繰り返し実行し、失敗率を測る。

使い方 (uv で実行する):
    uv run repro_rate.py -n 30 -- <コマンド> [引数...]
    uv run repro_rate.py -n 50 --timeout 120 --stop-on-fail -- pytest tests/test_x.py

終了コードが 0 以外、またはタイムアウトした回を失敗として数える。
最初に失敗した回の出力を表示する。修正前後で、同じ回数と同じ条件で回して比較する。

測定を歪めないために、次のようにしてある。
- 各回は新しいプロセスグループで起動する。タイムアウトしたら、コマンドが起こした
  子や孫のプロセスもまとめて止める。残ったプロセスが次の回に干渉しないようにするため。
- 標準入力は空にする。1 回目が入力を読み切り、2 回目以降だけ失敗する、という
  見かけの失敗を避けるため。
- `uv run` が足した一時的な仮想環境を、コマンドに渡す環境から取り除く (child_env を参照)。

入力待ちになるコマンドや、終わらない可能性のあるコマンドには --timeout を付ける。
既定では時間制限がない。
"""

import argparse
import os
import signal
import subprocess
import sys
import time


def child_env() -> dict:
    """測定対象のコマンドに渡す環境変数を返す。

    uv run はこのスクリプト用の一時的な仮想環境を PATH の先頭と VIRTUAL_ENV に入れる。
    そのまま子プロセスへ渡すと、対象のコマンドの python がプロジェクトのものではなく
    一時環境のものになり、依存が見つからない、版が違う、といった別の失敗を測ってしまう。
    ここでその分だけを取り除く。呼び出し元で仮想環境が有効だった場合は、その環境を
    VIRTUAL_ENV に入れ直す (uv が上書きした元の値は環境からは読めないため、PATH の
    先頭から推定する)。
    """
    env = dict(os.environ)
    own = os.path.realpath(sys.prefix)
    if not (env.get("VIRTUAL_ENV") and os.path.realpath(env["VIRTUAL_ENV"]) == own):
        return env
    bin_name = "Scripts" if os.name == "nt" else "bin"
    own_bin = os.path.join(own, bin_name)
    parts = [d for d in env.get("PATH", "").split(os.pathsep) if d and os.path.realpath(d) != own_bin]
    env["PATH"] = os.pathsep.join(parts)
    env.pop("UV_RUN_RECURSION_DEPTH", None)
    del env["VIRTUAL_ENV"]
    # 仮想環境を有効にすると、その bin が PATH の先頭に入る。uv の分を除いた後の先頭が
    # 仮想環境の bin なら、それが呼び出し元で有効だった環境である。先頭以外にあるだけの
    # 環境は有効だったとは言えないので、入れ直さない。
    if parts:
        first = os.path.abspath(parts[0])
        parent = os.path.dirname(first)
        if os.path.basename(first) == bin_name and os.path.isfile(os.path.join(parent, "pyvenv.cfg")):
            env["VIRTUAL_ENV"] = parent
    return env


def kill_group(proc: subprocess.Popen) -> None:
    """コマンドと、それが起こした子や孫のプロセスをまとめて止める。"""
    try:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        else:
            os.killpg(proc.pid, signal.SIGKILL)
    except OSError:
        pass


def run_once(command, env, timeout):
    """1 回実行し、(失敗したか, 出力, 理由) を返す。"""
    popen_args = dict(
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
        env=env,
    )
    if os.name == "nt":
        popen_args["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        popen_args["start_new_session"] = True
    proc = subprocess.Popen(command, **popen_args)
    try:
        output, _ = proc.communicate(timeout=timeout)
        return proc.returncode != 0, output or "", f"exit {proc.returncode}"
    except subprocess.TimeoutExpired:
        kill_group(proc)
        try:
            output, _ = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            output = ""
        return True, output or "", f"timeout {timeout}s"
    except BaseException:
        # 中断された場合も、起こしたプロセスを残さない
        kill_group(proc)
        raise


def positive_int(text: str) -> int:
    value = int(text)
    if value < 1:
        raise argparse.ArgumentTypeError("1 以上を指定する")
    return value


def positive_float(text: str) -> float:
    value = float(text)
    if value <= 0:
        raise argparse.ArgumentTypeError("0 より大きい値を指定する")
    return value


def non_negative_int(text: str) -> int:
    value = int(text)
    if value < 0:
        raise argparse.ArgumentTypeError("0 以上を指定する")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="コマンドを繰り返し実行して失敗率を測る")
    parser.add_argument("-n", "--runs", type=positive_int, default=20, help="実行回数（既定: 20）")
    parser.add_argument("--timeout", type=positive_float, default=None, help="1 回あたりの制限時間（秒）。既定は制限なし")
    parser.add_argument("--stop-on-fail", action="store_true", help="最初の失敗で止める")
    parser.add_argument("--tail", type=non_negative_int, default=40, help="失敗時に表示する出力の末尾行数（既定: 40、0 で表示しない）")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="-- に続けて実行するコマンド")
    args = parser.parse_args()

    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("実行するコマンドを -- の後に指定する")

    env = child_env()
    failures = []
    first_failure_output = None
    started = time.monotonic()
    completed = 0
    interrupted = False

    try:
        for i in range(1, args.runs + 1):
            try:
                failed, output, reason = run_once(command, env, args.timeout)
            except OSError as exc:
                # コマンドが見つからない、実行できない、など。測定ではなく呼び出しの誤り
                print(f"コマンドを実行できない: {command[0]}: {exc}", file=sys.stderr)
                return 2
            completed = i
            if failed:
                failures.append((i, reason))
                if first_failure_output is None:
                    first_failure_output = output
                if args.stop_on_fail:
                    break
    except KeyboardInterrupt:
        interrupted = True

    elapsed = time.monotonic() - started
    if completed == 0:
        print("1 回も完了しなかった", file=sys.stderr)
        return 130 if interrupted else 2
    rate = len(failures) / completed * 100
    note = "（中断された。ここまでの集計）" if interrupted else ""
    print(f"実行: {completed} 回 / 失敗: {len(failures)} 回 ({rate:.1f}%) / 所要: {elapsed:.1f} 秒{note}")
    if failures:
        print("失敗した回: " + ", ".join(f"#{i} ({reason})" for i, reason in failures))
        if args.tail > 0:
            print(f"--- 最初の失敗 (#{failures[0][0]}) の出力（末尾 {args.tail} 行） ---")
            print("\n".join((first_failure_output or "").splitlines()[-args.tail:]))
    if interrupted:
        return 130
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
