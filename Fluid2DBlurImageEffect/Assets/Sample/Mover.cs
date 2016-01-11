using UnityEngine;
using System.Collections;

public class Mover : MonoBehaviour {

	Vector3 _position = Vector3.right;
	float   _speed    = 1.0f;
	
	void Start () {

		_position = Random.insideUnitSphere * Random.Range (4.0f, 4.0f);
		transform.localPosition    = _position;
		transform.localEulerAngles = Random.insideUnitSphere * 360.0f;

		_speed = Random.Range (50.0f, 100.0f);
	}
	
	void Update () {

		transform.RotateAround (Vector3.zero, Vector3.Cross (Vector3.right, _position), Time.deltaTime * _speed);

	}
}
